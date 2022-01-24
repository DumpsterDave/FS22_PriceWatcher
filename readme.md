# Price Watcher for Farming Simulator 2022
![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/DumpsterDave/FS22_PriceWatcher?include_prereleases)
![GitHub release (latest by date)](https://img.shields.io/github/downloads/DumpsterDave/FS22_PriceWatcher/latest/total)
![GitHub issues](https://img.shields.io/github/issues/DumpsterDave/FS22_PriceWatcher)

[Download the latest version](https://github.com/DumpsterDave/FS22_PriceWatcher/releases/latest)

Join us on Discord: ![Discord](https://img.shields.io/discord/229813128144093184?label=DEFCON%201%20Gaming%20Discord)

## About
Price Watcher is a simple mod that tracks prices and notifies you when the specified threshold is hit.  The mod will track the revolving 13 month prices as well as all-time recorded high price.  Goods that are fixed price (Livestock, etc.) or can not be sold (Seeds/Fertilizer/Herbicide/etc) are not tracked.

## Configuration
Upon first use, a config XML will be generated in the modSettings folder.  The default path for this file is C:\Users\<username>\My Games\FarmingSimulator2022\modSettings.  Once generated, you can customize what items are tracked by setting them to true or false.
### Configure Tracking
`<SOYBEANS>false</SOYBEANS>` can be changed to `<SOYBEANS>true</SOYBEANS>` to start tracking Soybeans.
### Configure Price Threshold
```xml
<PriceThreshold>0.950000</PriceThreshold>
```

The price threshold is the point at which Price Watcher sends a notification about a high price.  By default, this set to 95%.  Any positive decimal value between 0 and 1 can be used.  Note that the lower the threshold is set, the more alerts you will get.
### Configure Notification Duration
```xml
<NotificationDuration>10</NotificationDuration>
```

The notification duration is the number of seconds a notification will remain on the screen.  Depending on your game speed settings and number of items tracked, setting this value too high could impact other notifications such as worker wages, mission completion, great demands, etc.  The default value is 10.
### Configure Colors
```xml
<AllTimeHighColor>0.767 0.006 0.006 1</AllTimeHighColor>
<AnnualHighColor>1 0.687 0 1</AnnualHighColor>
<NewAnnualHighColor>0.0976 0.624 0 1</NewAnnualHighColor>
<HighPriceColor>0 0.235 0.797 1</HighPriceColor>
```

The color of notifications can be configured by setting the RGBA value.  Note that these values are linear RGB.  You can use an online calculator such as [davengrace's Color Space Conversion](http://davengrace.com/cgi-bin/cspace.pl) to convert 8-bit sRGB values to their linear counterparts.

## Translations
Price Watcher is currently available in the following languages:
* English

## Support
