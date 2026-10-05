[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[BindToDefaultDestination = true]
shared silver_bookings = let
    Source = bronze_bookings,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"booking_id", Int64.Type}, {"guest_id", Int64.Type}, {"room_id", Int64.Type}, {"check_in", type date}, {"check_out", type date}, {"status", type text}}),
  #"Replaced value in status" = Table.ReplaceValue(#"Changed column type", "_", " ", Replacer.ReplaceText, {"status"}),
  #"Capitalized each word in status" = Table.TransformColumns(#"Replaced value in status", {{"status", each Text.Proper(_), type nullable text}})
in
    #"Capitalized each word in status";
[BindToDefaultDestination = true]
shared silver_guests = let
    Source = bronze_guests,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"guest_id", Int64.Type}, {"name", type text}, {"email", type text}, {"country", type text}, {"phone", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared silver_hotels = let
    Source = bronze_hotels,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"name", type text}, {"city", type text}, {"country", type text}, {"rating", type number}, {"hotel_id", Int64.Type}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared silver_reviews = let
    Source = bronze_reviews,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"review_id", Int64.Type}, {"booking_id", Int64.Type}, {"rating", Int64.Type}, {"comment", type text}})
in
  #"Changed column type";
[BindToDefaultDestination = true]
shared silver_rooms = let
    Source = bronze_rooms,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"room_id", Int64.Type}, {"hotel_id", Int64.Type}, {"price_per_night", Int64.Type}, {"room_type", type text}, {"is_available", type text}})
in
  #"Changed column type";
shared bronze_bookings = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "1c761ff9-684e-419c-8ad1-5216c5647b75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.bronze_bookings", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared bronze_guests = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "1c761ff9-684e-419c-8ad1-5216c5647b75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.bronze_guests", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared bronze_hotels = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "1c761ff9-684e-419c-8ad1-5216c5647b75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.bronze_hotels", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared bronze_reviews = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "1c761ff9-684e-419c-8ad1-5216c5647b75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.bronze_reviews", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared bronze_rooms = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "1c761ff9-684e-419c-8ad1-5216c5647b75"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "bronze.bronze_rooms", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
shared DefaultDestination = let
  Source = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1c761ff9-684e-419c-8ad1-5216c5647b75"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver", ItemKind = "Schema"]}[Data]
in
  #"Navigation 3";
