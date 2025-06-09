
--- 

## Human Notes

*Of course, the README and the code are written by Gemini! 😂*

### Original Sources of Inspiration:

*   [MQL5 - Product 53570](https://www.mql5.com/en/market/product/53570)
*   [MQL5 - Product 124993](https://www.mql5.com/en/market/product/124993)
*   [MQL5 - Product 37577](https://www.mql5.com/en/market/product/37577)
*   [GitHub - EarnForex/Breakeven-Line](https://github.com/EarnForex/Breakeven-Line)

### Pine Script Version of a Similar Indicator:

*   [TradingView - HMA Heiken Ashi Ribbons with Ichimoku](https://www.tradingview.com/script/uo2Da24X-HMA-Heiken-Ashi-Ribbons-with-Ichimoku/)

---

If you find this indicator useful and profitable, please consider supporting the original creators by purchasing their work. They are good people doing good work! 🤓👍

---
---
---
---
---








# MTF Double HMA Indicator for MetaTrader 5

A robust, self-contained, and high-performance dual-mode Hull Moving Average (HMA) indicator for MT5. It features non-repainting signals, a multi-timeframe dashboard, and a unique higher-timeframe bar preview with time-correct projection lines.


*(**Suggestion**: Replace the link above with a direct link to a screenshot of your indicator in action. This is highly recommended.)*

---

## Table of Contents

- [Key Features](#key-features)
- [How to Interpret](#how-to-interpret)
  - [Moving Averages](#moving-averages)
  - [Signal Arrows](#signal-arrows)
  - [Multi-Timeframe Dashboard](#multi-timeframe-dashboard)
  - [Higher Timeframe (HTF) Bar Preview](#higher-timeframe-htf-bar-preview)
  - [Information & Trade Panel](#information--trade-panel)
- [Installation](#installation)
- [Configuration Parameters](#configuration-parameters)
  - [Timeframe & Periods](#timeframe--periods)
  - [Display Settings](#display-settings)
  - [HTF Bar Preview](#htf-bar-preview-1)
  - [Alert Settings](#alert-settings)
- [Disclaimer](#disclaimer)

## Key Features

- **Dual HMA Lines**: Simultaneously displays a Hull Moving Average from a higher timeframe (MTF HMA) and the current chart's timeframe for trend context and entry timing.
- **Non-Repainting Signals**: The core logic for alerts is based on the state of the *closed* previous candle, ensuring signals do not repaint.
- **Multi-Timeframe Dashboard**: Get an at-a-glance view of the HMA trend direction across 9 different timeframes (M1 to Monthly). The dashboard is interactive, allowing you to switch timeframes or toggle alerts.
- **Higher Timeframe (HTF) Bar Preview**: Visualizes the current, developing HTF candle directly on your chart, including its open, high, low, and close levels. This provides critical context without needing to switch charts.
- **Live Trade Information Panel**:
  - Displays market status and live spread.
  - Shows countdown timers for the close of the current and HTF bars.
  - Automatically calculates and displays break-even price lines for open long and short positions.
  - Includes "preview" break-even lines that factor in pending orders.
- **Customizable Alerts**: Receive alerts for trend changes via on-screen pop-ups, sound, email, and push notifications.

## How to Interpret

### Moving Averages

- **Thick Line (MTF HMA)**: This is the Hull Moving Average calculated on the higher timeframe you select (e.g., H4). It represents the major, underlying trend.
  - `DeepSkyBlue`: Major trend is bullish.
  - `Orange`: Major trend is bearish.
- **Thin Line (Current TF HMA)**: This is the HMA for the timeframe of your current chart. It represents the shorter-term trend and can be used for entry signals.

### Signal Arrows

- **Large Arrows**: Indicate a trend change on the **MTF HMA**. These signal a significant shift in the underlying market direction.
- **Small Arrows**: Indicate a trend change on the **Current TF HMA** that is aligned with the major trend. For example, a small blue "up" arrow will only appear if the MTF HMA is also bullish (blue). These are potential entry signals.

### Multi-Timeframe Dashboard

The dashboard at the top of the chart shows the HMA status for multiple timeframes.

- **Color**: `Blue` for uptrend, `Orange` for downtrend.
- **`!` Symbol**: Indicates a potential trend change is in progress, but the candle has **not yet closed**. This is a "heads-up" signal.
- **`?` Symbol**: Indicates a very recent trend change where the current candle has changed direction compared to the previous one. This signals potential instability or a reversal attempt.
- **No Symbol**: A stable, confirmed trend.
- **Clickable Box**: Clicking the timeframe box (e.g., "H1") will instantly change your current chart to that timeframe.
- **`!` Button**: Clicking the "!" button next to a timeframe toggles final alerts for that specific timeframe.

### Higher Timeframe (HTF) Bar Preview

This feature projects the HTF candle onto your current chart, helping you visualize its development in real-time.

- **Rectangle Body**: The solid body of the HTF candle.
- **Thin Wick**: The upper and lower wicks.
- **Dotted Lines**: Horizontal lines project the Open, High, Low, and Close prices of the HTF bar across your chart, acting as dynamic support and resistance levels.

### Information & Trade Panel

Located in the top-right corner, this panel provides live data:

- **Market Status & Spread**: Shows if the market is open and displays the live spread.
- **Candle Timers**: Countdown to the close of the current bar and the HTF bar.
- **Break-Even (BE) Lines**:
  - **Long/Short BE (Solid Lines)**: The volume-weighted average entry price for all open buy or sell positions.
  - **Preview BE (Dashed Lines)**: The projected break-even price if all pending orders (stops/limits) were to be filled.
  - **Net BE (Gold Line)**: The break-even price for a hedged position (when both long and short trades are open).

## Installation

1.  Download the `mtf-hma-indicator.mq5` file.
2.  Open your MetaTrader 5 terminal.
3.  Go to `File` -> `Open Data Folder`.
4.  Navigate to the `MQL5` -> `Indicators` folder.
5.  Copy and paste the `mtf-hma-indicator.mq5` file into this folder.
6.  Return to MetaTrader 5. Right-click on the "Indicators" list in the "Navigator" window and click `Refresh`.
7.  The "MTF HMA Indicator" will now appear in your list of indicators. Drag it onto a chart to use it.

## Configuration Parameters

All inputs are fully customizable to suit your trading style.

#### Timeframe & Periods

| Parameter          | Description                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| `InpTimeFrame`     | The higher timeframe to use for the main HMA and the HTF Bar Preview.       |
| `InpHigherTfPeriod`| The period (number of bars) for the higher timeframe HMA.                   |
| `InpCurrentTfPeriod`| The period for the HMA on the current chart. Set to `0` to disable.        |
| `InpPrice`         | The price to use for HMA calculations (Close, Open, High, Low, etc.).       |

#### Display Settings

| Parameter          | Description                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| `InpShowDashboard` | Show or hide the multi-timeframe dashboard.                                 |
| `InpArrowOffsetPips`| The distance in pips to draw the signal arrows away from the high/low.      |
| `InpMtfArrowSize`  | The size of the large arrows (MTF signals).                                 |
| `InpCurArrowSize`  | The size of the small arrows (Current TF signals).                          |

#### HTF Bar Preview

| Parameter          | Description                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| `InpShowHtfBar`    | Show or hide the projected HTF bar visualization.                           |
| `InpHtfBarShift`   | How many bars to shift the projected candle to the right.                   |
| `InpHtfBarScale`   | The vertical scale of the projected candle. Use `<1.0` to shrink, `>1.0` to enlarge. |
| `InpHtfBarBullColor` | Color of a bullish HTF bar.                                               |
| `InpHtfBarBearColor` | Color of a bearish HTF bar.                                               |
| `InpShowHtfLines`  | Show or hide the horizontal projection lines (O, H, L, C).                  |
| `InpHtfLineColor`  | Color of the projection lines.                                              |
| `InpHtfLineStyle`  | Style of the projection lines (e.g., Dot, Dash).                            |

#### Alert Settings

| Parameter        | Description                                                                 |
| ---------------- | --------------------------------------------------------------------------- |
| `InpEnableAlerts`| Enable/disable the on-screen `Alert()` pop-up window.                       |
| `InpEnableSound` | Enable/disable sound alerts.                                                |
| `InpEnableMail`  | Enable/disable email alerts (requires Mail setup in MT5 options).           |
| `InpEnablePush`  | Enable/disable push notifications to your mobile device (requires setup).   |
| `InpSoundFinal`  | Sound file to play for a final, confirmed signal (e.g., `alert.wav`).       |
| `InpSoundPossible`| Sound file to play for a possible, unconfirmed signal (e.g., `request.wav`).|

---

## Disclaimer

This indicator is a tool for technical analysis and should not be considered as financial advice. Trading foreign exchange, CFDs, and other financial instruments carries a high level of risk and may not be suitable for all investors. You should not invest money that you cannot afford to lose. Before deciding to trade, you should be aware of all the risks associated with trading and seek advice from an independent financial advisor if you have any doubts. The author is not responsible for any losses incurred as a result of using this indicator.

