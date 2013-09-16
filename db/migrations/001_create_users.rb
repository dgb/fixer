Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email
      String :dropbox_uid
      String :dropbox_name
      String :dropbox_token
      String :dropbox_secret
      String :dropbox_delta
      DateTime :created_at, :null => false
      DateTime :updated_at, :null => false
    end
  end
end
