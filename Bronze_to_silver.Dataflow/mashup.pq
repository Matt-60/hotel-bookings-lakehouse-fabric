[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared silver_bookings = let
    Source = bronze_bookings,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"booking_id", Int64.Type}, {"guest_id", Int64.Type}, {"room_id", Int64.Type}, {"check_in", type date}, {"check_out", type date}, {"status", type text}}),
  #"Replaced value in status" = Table.ReplaceValue(#"Changed column type", "_", " ", Replacer.ReplaceText, {"status"}),
  #"Capitalized each word in status" = Table.TransformColumns(#"Replaced value in status", {{"status", each Text.Proper(_), type nullable text}})
in
    #"Capitalized each word in status";
shared silver_guests = let
    Source = bronze_guests,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"guest_id", Int64.Type}, {"name", type text}, {"email", type text}, {"country", type text}, {"phone", type text}})
in
  #"Changed column type";
shared silver_hotels = let
    Source = bronze_hotels,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"name", type text}, {"city", type text}, {"country", type text}, {"rating", type number}, {"hotel_id", Int64.Type}})
in
  #"Changed column type";
shared silver_reviews = let
    Source = bronze_reviews,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"review_id", Int64.Type}, {"booking_id", Int64.Type}, {"rating", Int64.Type}, {"comment", type text}}),
  #"Grouped rows" = Table.Group(#"Changed column type", {"booking_id"}, {{"avg_rating", each List.Average([rating]), type nullable number}}),
  #"Rounded off" = Table.TransformColumns(#"Grouped rows", {{"avg_rating", each Number.Round(_, 1), type number}})
in
  #"Rounded off";
shared silver_rooms = let
    Source = bronze_rooms,
  #"Changed column type" = Table.TransformColumnTypes(Source, {{"room_id", Int64.Type}, {"hotel_id", Int64.Type}, {"price_per_night", Int64.Type}, {"room_type", type text}, {"is_available", type text}})
in
  #"Changed column type";
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "silver_obt_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared silver_obt = let
  Source = silver_bookings,
  #"Merged guests"= Table.NestedJoin(Source, {"guest_id"}, silver_guests, {"guest_id"}, "silver_guests", JoinKind.LeftOuter),
  #"Merged rooms" = Table.NestedJoin(#"Merged guests", {"room_id"}, silver_rooms, {"room_id"}, "silver_rooms", JoinKind.LeftOuter),
  #"Expanded guests" = Table.ExpandTableColumn(#"Merged rooms", "silver_guests", {"name", "email", "phone", "country"}, {"name", "email", "phone", "country"}),
  #"Expanded rooms" = Table.ExpandTableColumn(#"Expanded guests", "silver_rooms", {"hotel_id", "room_type", "price_per_night", "is_available"}, {"hotel_id", "room_type", "price_per_night", "is_available"}),
  #"Merged hotels" = Table.NestedJoin(#"Expanded rooms", {"hotel_id"}, silver_hotels, {"hotel_id"}, "silver_hotels", JoinKind.LeftOuter),
  #"Merged reviews" = Table.NestedJoin(#"Merged hotels", {"booking_id"}, silver_reviews, {"booking_id"}, "silver_reviews", JoinKind.LeftOuter),
  #"Expanded hotels" = Table.ExpandTableColumn(#"Merged reviews", "silver_hotels", {"name", "city", "country", "rating"}, {"name.1", "city", "country.1", "rating"}),
  #"Expanded reviews" = Table.ExpandTableColumn(#"Expanded hotels", "silver_reviews", {"avg_rating"}, {"avg_rating"}),
  #"Renamed columns" = Table.RenameColumns(#"Expanded reviews", {{"status", "booking_status"}, {"name", "guest_name"}, {"is_available", "room_is_available"}, {"name.1", "hotel_name"}, {"city", "hotel_city"}, {"country.1", "hotel_country"}, {"rating", "hotel_rating"}, {"avg_rating", "review_rating"}, {"email", "guest_email"}, {"phone", "guest_phone"}, {"country", "guest_country"}}),
  #"Added custom column nights_stayed" = Table.AddColumn(#"Renamed columns", "nights_stayed", each Duration.Days([check_out] - [check_in])),
  #"Added custom column total_price" = Table.AddColumn(#"Added custom column nights_stayed", "total_price", each [nights_stayed] * [price_per_night]),
  #"Added custom column is_reviewed" = Table.AddColumn(#"Added custom column total_price", "is_reviewed", each if [review_rating] = null then "False" else "True"),
  #"Changed custom columns type" = Table.TransformColumnTypes(#"Added custom column is_reviewed", {{"nights_stayed", Int64.Type}, {"total_price", Int64.Type}, {"is_reviewed", type text}}),
  #"Reordered columns" = Table.ReorderColumns(#"Changed custom columns type", {"booking_id", "guest_id", "room_id", "hotel_id", "price_per_night", "nights_stayed", "total_price", "review_rating", "check_in", "check_out", "booking_status", "is_reviewed", "guest_name", "guest_email", "guest_phone", "guest_country", "room_type", "room_is_available", "hotel_name", "hotel_city", "hotel_country", "hotel_rating"}),
  #"Added silver_processed_date columns" = Table.AddColumn(#"Reordered columns", "silver_processed_date", each DateTime.LocalNow()),
  #"Changed silver_processed_date column type" = Table.TransformColumnTypes(#"Added silver_processed_date columns", {{"silver_processed_date", type datetime}})
in
  #"Changed silver_processed_date column type";
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
shared silver_obt_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false, HierarchicalNavigation = true, EnableVorder = true, OutputMetadataRefresh = true]),
  Navigation_1 = Pattern{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  Navigation_3 = Navigation_2{[Id = "silver", ItemKind = "Schema"]}[Data],
  TableNavigation = Navigation_3{[Id = "silver_obt", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
