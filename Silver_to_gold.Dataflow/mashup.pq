[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data]{[lakehouseId = "78969ec5-5b1b-44b6-9672-dc432d5eba29"]}[Data];
[BindToDefaultDestination = true]
shared dim_date = let
    Fact      = silver_bookings,
    StartDate = List.Min(Fact[check_in]),
    EndDate   = List.Max(Fact[check_out]),

    DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    ChangeType = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddYear = Table.AddColumn(ChangeType, "year", each Date.Year([Date]), Int32.Type),
    AddMonth = Table.AddColumn(AddYear, "month", each Date.Month([Date]), Int32.Type),
    AddMonthName = Table.AddColumn(AddMonth, "month_name", each Date.ToText([Date], [Format = "MMMM", Culture = "en-US"]), type text),
    AddQuarter = Table.AddColumn(AddMonthName, "quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddDay = Table.AddColumn(AddQuarter, "day", each Date.Day([Date]), Int32.Type),
    AddDayName = Table.AddColumn(AddDay, "day_name", each Date.ToText([Date], [Format = "dddd", Culture = "en-US"]), type text),
    AddDayOfWeek = Table.AddColumn(AddDayName, "day_of_week", each Date.DayOfWeek([Date], Day.Monday) + 1, Int32.Type),
    AddIsWeekend = Table.AddColumn(AddDayOfWeek, "is_weekend", each [day_of_week] >= 6, type logical)
in
    AddIsWeekend;
shared silver_bookings = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_bookings", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared silver_guests = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_guests", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared silver_hotels = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_hotels", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared silver_reviews = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_reviews", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared silver_rooms = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_rooms", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
[BindToDefaultDestination = true]
shared dim_guests = let
  Source = silver_guests
in
  Source;
shared #"fact_bookings(staging)" = let
  Source = Table.NestedJoin(silver_bookings, {"booking_id"}, silver_reviews_agg, {"booking_id"}, "silver_reviews_agg", JoinKind.LeftOuter),
  #"Expanded silver_reviews_agg" = Table.ExpandTableColumn(Source, "silver_reviews_agg", {"avg_rating"}, {"avg_rating"}),
  #"Merged queries" = Table.NestedJoin(#"Expanded silver_reviews_agg", {"room_id"}, silver_rooms, {"room_id"}, "silver silver_rooms", JoinKind.LeftOuter),
  #"Expanded silver silver_rooms" = Table.ExpandTableColumn(#"Merged queries", "silver silver_rooms", {"hotel_id", "price_per_night"}, {"hotel_id", "price_per_night"}),
  #"Reordered columns" = Table.ReorderColumns(#"Expanded silver silver_rooms", {"booking_id", "guest_id", "room_id", "hotel_id", "check_in", "check_out", "price_per_night", "avg_rating", "status"}),
  #"Added custom" = Table.TransformColumnTypes(Table.AddColumn(#"Reordered columns", "nights_stayed_in", each [check_out] - [check_in]), {{"nights_stayed_in", Int64.Type}}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Added custom", {"booking_id", "guest_id", "room_id", "hotel_id", "check_in", "check_out", "nights_stayed_in", "price_per_night", "avg_rating", "status"}),
  #"Added custom 1" = Table.TransformColumnTypes(Table.AddColumn(#"Reordered columns 1", "total_price", each [price_per_night] * [nights_stayed_in]), {{"total_price", Int64.Type}}),
  #"Reordered columns 2" = Table.ReorderColumns(#"Added custom 1", {"booking_id", "guest_id", "room_id", "hotel_id", "check_in", "check_out", "nights_stayed_in", "price_per_night", "total_price", "avg_rating", "status"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns 2", {{"avg_rating", "review_rating"}, {"nights_stayed_in", "nights_stayed"}, {"status", "booking_status"}}),
  #"Removed columns" = Table.RemoveColumns(#"Renamed columns", {"hotel_id"})
in
  #"Removed columns";
[BindToDefaultDestination = true]
shared dim_rooms = let
  Source = silver_rooms,
  #"Merged queries" = Table.NestedJoin(Source, {"hotel_id"}, silver_hotels, {"hotel_id"}, "silver silver_hotels", JoinKind.LeftOuter),
  #"Expanded silver silver_hotels" = Table.ExpandTableColumn(#"Merged queries", "silver silver_hotels", {"name", "city", "country", "rating"}, {"hotel_name", "hotel_city", "hotel_country", "hotel_rating"})
in
  #"Expanded silver silver_hotels";
shared silver_reviews_agg = let
  Source = silver_reviews,
  #"Grouped rows" = Table.Group(Source, {"booking_id"}, {{"avg_rating", each List.Average([rating]), type nullable number}})
in
  #"Grouped rows";
[BindToDefaultDestination = true]
shared fact_stay_nights = let
  Source = #"fact_bookings(staging)",
  AddNights = Table.AddColumn(Source, "stay_date",
      each List.Dates([check_in], [nights_stayed], #duration(1, 0, 0, 0))),
  Expanded = Table.ExpandListColumn(AddNights, "stay_date"),
  Typed = Table.TransformColumnTypes(Expanded, {{"stay_date", type date}}),
  AddFirstNight = Table.AddColumn(Typed, "is_first_night", each [stay_date] = [check_in], type logical),
  Renamed = Table.RenameColumns(AddFirstNight, {{"price_per_night", "room_revenue"}}),
  Result = Table.RemoveColumns(Renamed, {"total_price"})
in
  Result;
