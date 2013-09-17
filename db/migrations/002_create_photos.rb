Sequel.migration do
  change do
    create_table(:photos) do
      primary_key :id
      foreign_key :user_id, :users
      String :state
      String :dropbox_path
      String :dropbox_rev
      Integer :iso
      Float :f_stop
      Float :exposure_time
      Float :focal_length
      String :path
      Integer :height
      Integer :width
      DateTime :taken_at
      DateTime :created_at, :null => false
      DateTime :updated_at, :null => false
    end
  end
end
