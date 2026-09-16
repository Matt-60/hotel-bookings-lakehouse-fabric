[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared Silver_OBT = let
  Source = Lakehouse.Contents(null),
  Navigation = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 1" = Navigation{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Id = "silver.silver_obt", ItemKind = "Table"]}[Data]
in
  #"Navigation 2";
[BindToDefaultDestination = true]
shared dim_flags = let
  Source = Silver_OBT,
  #"Removed other columns" = Table.SelectColumns(#"Source", {"is_reviewed", "booking_status"}),
  #"Removed duplicates" = Table.Distinct(#"Removed other columns", {"booking_status", "is_reviewed"}),
  #"Added index" = Table.AddIndexColumn(#"Removed duplicates", "Index", 1, 1, Int64.Type),
  #"Reordered columns" = Table.ReorderColumns(#"Added index", {"Index", "is_reviewed", "booking_status"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"Index", "flag_id"}})
in
  #"Renamed columns";
[BindToDefaultDestination = true]
shared fact_bookings = let
  Source = Silver_OBT,
  #"Merged flags" = Table.NestedJoin(Source, {"booking_status", "is_reviewed"}, dim_flags, {"booking_status", "is_reviewed"}, "dim_flags", JoinKind.LeftOuter),
  #"Expanded dim_flags" = Table.ExpandTableColumn(#"Merged flags", "dim_flags", {"flag_id"}, {"flag_id"}),
  #"Removed columns" = Table.RemoveColumns(#"Expanded dim_flags", {"hotel_rating", "booking_status", "guest_name", "guest_email", "guest_phone", "guest_country", "room_type", "room_is_available", "hotel_name", "hotel_city", "hotel_country", "is_reviewed"}),
  #"Reordered columns" = Table.ReorderColumns(#"Removed columns", {"booking_id", "guest_id", "room_id", "hotel_id", "flag_id", "price_per_night", "nights_stayed", "total_price", "review_rating", "check_in", "check_out", "silver_processed_date"}),
  #"Added gold_processed_date" = Table.AddColumn(#"Reordered columns", "gold_processed_date", each DateTime.LocalNow()),
  #"Changed gold_processed_date column type" = Table.TransformColumnTypes(#"Added gold_processed_date", {{"gold_processed_date", type datetime}}),
  #"Sorted rows" = Table.Sort(#"Changed gold_processed_date column type", {{"booking_id", Order.Ascending}})
in
  #"Sorted rows";
[BindToDefaultDestination = true]
shared dim_hotels = let
  Source = Silver_OBT,
  #"Removed columns" = Table.RemoveColumns(#"Source", {"booking_id", "guest_id", "room_id", "price_per_night", "total_price", "review_rating", "check_in", "check_out", "nights_stayed", "booking_status", "guest_name", "guest_email", "guest_phone", "guest_country", "is_reviewed", "silver_processed_date"}),
  #"Removed duplicates" = Table.Distinct(#"Removed columns", {"hotel_id"}),
  #"Reordered columns" = Table.ReorderColumns(#"Removed duplicates", {"hotel_id", "hotel_name", "hotel_city", "hotel_country", "hotel_rating", "room_type", "room_is_available"}),
  #"Sorted rows" = Table.Sort(#"Reordered columns", {{"hotel_id", Order.Ascending}})
in
  #"Sorted rows";
[BindToDefaultDestination = true]
shared dim_guests = let
  Source = Silver_OBT,
  #"Removed columns" = Table.RemoveColumns(#"Source", {"silver_processed_date", "is_reviewed", "hotel_country", "hotel_city", "hotel_name", "room_is_available", "room_type", "booking_status", "nights_stayed", "check_out", "check_in", "review_rating", "hotel_rating", "total_price", "price_per_night", "hotel_id", "room_id", "booking_id"}),
  #"Removed duplicates" = Table.Distinct(#"Removed columns", {"guest_id"}),
  #"Sorted rows" = Table.Sort(#"Removed duplicates", {{"guest_id", Order.Ascending}})
in
  #"Sorted rows";
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data]{[lakehouseId = "78969ec5-5b1b-44b6-9672-dc432d5eba29"]}[Data];
[BindToDefaultDestination = true]
shared dim_date = let
    StartDate = #date(2025, 6, 1),
    EndDate = #date(2026, 7, 31),
    DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    ChangeType = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddYear = Table.AddColumn(ChangeType, "year", each Date.Year([Date]), Int32.Type),
    AddMonth = Table.AddColumn(AddYear, "month", each Date.Month([Date]), Int32.Type),
    AddMonthName = Table.AddColumn(AddMonth, "month_name", each Date.ToText([Date], "MMMM"), type text),
    AddQuarter = Table.AddColumn(AddMonthName, "quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddDay = Table.AddColumn(AddQuarter, "day", each Date.Day([Date]), Int32.Type),
    AddDayName = Table.AddColumn(AddDay, "day_name", each Date.ToText([Date], "dddd"), type text),
    AddIsWeekend = Table.AddColumn(AddDayName, "is_weekend", each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical)
in
    AddIsWeekend;
