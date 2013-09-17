require 'json'
require 'rational'
require 'tempfile'

require 'bundler'
Bundler.require

# Dropbox

Dropbox::API::Config.app_key    = ENV['DROPBOX_KEY']
Dropbox::API::Config.app_secret = ENV['DROPBOX_SECRET']
Dropbox::API::Config.mode       = "sandbox"

# Database

DB = Sequel.connect(ENV['DATABASE_URL'])

Sequel::Model.plugin :timestamps, :update_on_create => true
Sequel::Model.plugin :json_serializer, :naked => true
Sequel::Model.plugin :dirty

class User < Sequel::Model
  def dropbox
    @dropbox ||= Dropbox::API::Client.new(:token => dropbox_token, :secret => dropbox_secret)
  end

  def sync
    delta = dropbox.delta(dropbox_delta)
    self.update(:dropbox_delta => delta.cursor)
    delta.entries.each do |entry|
      photo = Photo.find_or_create(:user_id => self.id, :dropbox_path => entry.path)
      photo.set(:dropbox_rev => entry.rev)

      if entry.is_deleted
        photo.destroy
      elsif photo.column_changed?(:dropbox_rev)
        photo.process
      end
    end
  end

  def pretty_name
    dropbox_name.match(/(\w+)/)
    $1
  end
end

class Photo < Sequel::Model
  many_to_one :user

  state_machine :initial => :unprocessed do
    event :process do
      transition :unprocessed => :processing
    end

    after_transition :unprocessed => :processing do
      PhotoDeveloper.perform_async self.id
    end

    event :develop do
      transition :processing => :processed
    end

    event :reject do
      transition :processing => :failed
    end
  end

  def pretty_exposure_time
    exposure_time.rationalize(0.000001) if exposure_time
  end

  def pretty_taken_at
    taken_at.strftime("%-d %b %Y") if taken_at
  end

  def image
    Dragonfly[:images].fetch(path)
  end

  def image=(img)
    self.path = Dragonfly[:images].store(img)
    image.tap do |img|
      self.height = img.height
      self.width  = img.width
    end
  end

  def thumbnail
    image.thumb('280x280#')
  end

  def portrait?
    height >= width
  end
end

# Metadata

class Metadata
  def self.open(path)
    str = `exiv2 -Pkv pr "#{path}"`
    exif = str.scan(/([\w\.]+)\s+(.+)/)
    new(Hash[exif])
  end

  def initialize(exif)
    @exif = exif
  end

  def iso
    @exif['Exif.Photo.ISOSpeedRatings'].is_a?(Array) ? @exif['Exif.Photo.ISOSpeedRatings'].first : @exif['Exif.Photo.ISOSpeedRatings']
  end

  def exposure_time
    Rational(@exif['Exif.Photo.ExposureTime']).to_f
  end

  def f_stop
    Rational(@exif['Exif.Photo.FNumber']).to_f
  end

  def taken_at
    DateTime.strptime(@exif['Exif.Photo.DateTimeDigitized'], '%Y:%m:%d %H:%M:%S')
  end

  def focal_length
    Rational(@exif['Exif.Photo.FocalLengthIn35mmFilm']).to_f
  end

  def to_hash
    attrs = [:iso, :exposure_time, :f_stop, :taken_at, :focal_length].map { |a| [a, self.send(a)] }
    Hash[attrs]
  end
end

# Worker

class PhotoDeveloper
  include Sidekiq::Worker

  def perform(photo_id)
    photo = Photo[photo_id]
    user = photo.user

    temp = Tempfile.new('developing')
    body = user.dropbox.download(photo.dropbox_path)
    temp.write body
    temp.rewind

    out = Tempfile.new('output')
    out.close

    meta = Metadata.open(temp.path)

    res  = %x(ufraw-batch "#{temp.path}" --output "#{out.path}" --out-type=jpg --auto-crop --lensfun=auto --size=1536 --overwrite)

    if $?.success?
      photo.set(meta.to_hash)
      photo.set(:image => out)
      photo.develop
    else
      photo.reject
    end

    temp.unlink
    out.unlink
  end
end

# Dragonfly Middleware

Dragonfly[:images].configure_with(:imagemagick) do |c|
  c.url_format = '/media/:job'
  #c.url_host = 'media.fixerapp.com'# if ENV['RACK_ENV'] == 'production'
  c.datastore = Dragonfly::DataStorage::S3DataStore.new(
    :bucket_name => ENV['AWS_BUCKET'],
    :access_key_id => ENV['AWS_ID'],
    :secret_access_key => ENV['AWS_SECRET']
  )
end

use Dragonfly::Middleware, :images

# OmniAuth
use OmniAuth::Builder do
  provider :dropbox, ENV['DROPBOX_KEY'], ENV['DROPBOX_SECRET']
  provider :facebook, ENV['FACEBOOK_APP_ID'], ENV['FACEBOOK_SECRET'], :provider_ignores_state => true
end

# Settings

enable :sessions
set :database, DB

# Helpers

helpers do
  def current_user
    session[:current_user_id] && User[session[:current_user_id]]
  end

  def json(arg)
    content_type :json
    arg.to_json
  end

  def facebook_app_id
    ENV['FACEBOOK_APP_ID']
  end
end

get '/' do
  if current_user
    @photos     = Photo.where(:user_id => current_user.id, :state => 'processed').order(:taken_at).all
    @processing = Photo.where(:user_id => current_user.id, :state => 'processing').count
    erb :photos
  else
    erb :home, :layout => false
  end
end

get '/auth/dropbox/callback' do
  auth = request.env['omniauth.auth']
  @user = User.find_or_create(:dropbox_uid => auth.uid.to_s)
  @user.update(:dropbox_name => auth.info.name, :dropbox_token => auth.credentials.token, :dropbox_secret => auth.credentials.secret, :email => auth.info.email)
  session[:current_user_id] = @user.id
  @user.sync
  redirect to('/')
end

get '/photos/:id' do
  @photo = Photo[params[:id]]
  # halt 403 unless @photo.visible_to?(current_user)
  erb :photo
end
