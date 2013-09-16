Sequel.migration do
  change do
    create_table(:photos) do
      primary_key :id
      foreign_key :user_id, :users
      String :dropbox_path
      String :dropbox_rev
      String :state
      Integer :iso
      Float :f_stop
      Float :exposure_time
      Float :focal_length
      DateTime :taken_at
      DateTime :created_at, :null => false
      DateTime :updated_at, :null => false
    end
  end
end
