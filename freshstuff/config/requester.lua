-- Add a request.
Commands.AddReq = "addreq"
Levels.AddReq = 1

-- Show requests.
Commands.ShowReqs = "requests"
Levels.ShowReqs = 1

-- Delete requests. Note that everyone is allowed to delete their own requests.
Commands.DelReq = "delreq"
Levels.DelReq = 4

-- Link a release with a request thus fulfilling it.
Commands.LinkReq = "linkreq"
Levels.LinkReq = 1

-- Subscribe for requests.
Commands.SubscrReq = "subscrreq"
Levels.SubscrReq = 1

-- How many requests should be considered new?
MaxNewReq = 15

-- How many percent should be so two items are considered identical? 75 is a good
-- estimate but your mileage may vary.
MaxMatch = 75

-- How many items should be checked at once? My tests show that 40 is a good value.
-- You can raise this value, though, if you have a fast server but it may cause
-- undesirable lags in the hub so change this only at your own risk!
ItemsToCheckAtOnce = 40