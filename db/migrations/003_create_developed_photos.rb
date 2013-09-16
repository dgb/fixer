Sequel.migration do
  change do
    create_table(:developed_photos) do
      primary_key :id
      foreign_key :photo_id, :photos
      String :path
      Integer :exposure
      Integer :temperature
      Integer :height
      Integer :width
      DateTime :created_at, :null => false
      DateTime :updated_at, :null => false
    end
  end
end
