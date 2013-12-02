require_relative '../fixer'

describe Metadata do
  subject { Metadata.from_str(exif) }
  context 'when input is present' do
    let(:exif) do
      exif =<<-EOS
Exif.Photo.ISOSpeedRatings                    100
Exif.Photo.ExposureTime                       1/60
Exif.Photo.FNumber                            11/1
Exif.Photo.DateTimeDigitized                  2011:03:20 14:08:37
Exif.Photo.FocalLengthIn35mmFilm              27
      EOS
    end
  end
  context 'when input is blank' do
    let(:exif) { '' }
    its(:iso)           { should == nil }
    its(:exposure_time) { should == nil }
    its(:f_stop)        { should == nil }
    its(:taken_at)      { should == nil }
    its(:focal_length)  { should == nil }
  end
end
