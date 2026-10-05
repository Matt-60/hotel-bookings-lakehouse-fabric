[DefaultOutputDestinationSettings = [DestinationDefinition = [Kind = "Reference", QueryName = "DefaultDestination", IsNewTarget = true], UpdateMethod = [Kind = "Replace"], DestinationTypeSettings = [Kind = "Table"]], StagingDefinition = [Kind = "FastCopy"]]
section Section1;
shared DefaultDestination = Lakehouse.Contents([EnableFolding = false]){[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data]{[lakehouseId = "78969ec5-5b1b-44b6-9672-dc432d5eba29"]}[Data];
[BindToDefaultDestination = true]
shared dim_date = let
    Fact      = silver_bookings,
    MinDate   = List.Min(Fact[check_in]),
    MaxDate   = List.Max(Fact[check_out]),
    StartDate = Date.StartOfYear(MinDate),
    EndDate   = Date.EndOfYear(MaxDate),

    DateList = List.Dates(StartDate, Duration.Days(EndDate - StartDate) + 1, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    ChangeType = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddYear = Table.AddColumn(ChangeType, "year", each Date.Year([Date]), Int32.Type),
    AddMonth = Table.AddColumn(AddYear, "month", each Date.Month([Date]), Int32.Type),
    AddMonthName = Table.AddColumn(AddMonth, "month_name", each Date.ToText([Date], [Format = "MMMM", Culture = "en-US"]), type text),
    AddQuarter = Table.AddColumn(AddMonthName, "quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddDay = Table.AddColumn(AddQuarter, "day", each Date.Day([Date]), Int32.Type),
    AddDayName = Table.AddColumn(AddDay, "day_name", each Date.ToText([Date], [Format = "dddd", Culture = "en-US"]), type text),
    AddIsWeekend = Table.AddColumn(AddDayName, "is_weekend", each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical)
in
    AddIsWeekend;
shared silver_bookings = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_bookings", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"silver silver_guests" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_guests", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"silver silver_hotels" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_hotels", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"silver silver_reviews" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_reviews", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
shared #"silver silver_rooms" = let
  Source = Lakehouse.Contents([HierarchicalNavigation = null, EnableVorder = true, OutputMetadataRefresh = true]),
  #"Navigation 1" = Source{[workspaceId = "ea2d8afd-031d-4660-b557-4daa26dc7cad"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[lakehouseId = "1604b554-d8b5-41da-9253-b8626d725ff0"]}[Data],
  #"Navigation 3" = #"Navigation 2"{[Id = "silver.silver_rooms", ItemKind = "Table"]}[Data]
in
  #"Navigation 3";
[BindToDefaultDestination = true]
shared dim_guests = let
  Source = #"silver silver_guests"
in
  Source;
[BindToDefaultDestination = true]
shared fact_bookings = let
  Source = Table.NestedJoin(silver_bookings, {"booking_id"}, #"silver silver_reviews", {"booking_id"}, "silver silver_reviews", JoinKind.LeftOuter),
  #"Expanded silver silver_reviews" = Table.ExpandTableColumn(Source, "silver silver_reviews", {"avg_rating"}, {"avg_rating"}),
  #"Merged queries" = Table.NestedJoin(#"Expanded silver silver_reviews", {"room_id"}, #"silver silver_rooms", {"room_id"}, "silver silver_rooms", JoinKind.LeftOuter),
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
  Source = #"silver silver_rooms",
  #"Merged queries" = Table.NestedJoin(Source, {"hotel_id"}, #"silver silver_hotels", {"hotel_id"}, "silver silver_hotels", JoinKind.LeftOuter),
  #"Expanded silver silver_hotels" = Table.ExpandTableColumn(#"Merged queries", "silver silver_hotels", {"name", "city", "country", "rating"}, {"hotel_name", "hotel_city", "hotel_country", "hotel_rating"})
in
  #"Expanded silver silver_hotels";
