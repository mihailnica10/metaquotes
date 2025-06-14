#property copyright "Gemini"
#property link      "https://www.google.com"
#property description "A robust, self-contained, and high-performance dual-mode MTF HMA with non-repainting signals and a scalable HTF bar preview with time-correct projection lines. Final version."
#property version   "7.8"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   2

#property indicator_label1  "MTF HMA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  DeepSkyBlue,Orange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  5

#property indicator_label2  "Current TF HMA"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  DeepSkyBlue,Orange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

input group              "Timeframe & Periods"
input ENUM_TIMEFRAMES    InpTimeFrame      = PERIOD_H4;
input int                InpHigherTfPeriod = 12;
input int                InpCurrentTfPeriod= 12;
input ENUM_APPLIED_PRICE InpPrice          = PRICE_CLOSE;

input group              "Display Settings"
input bool               InpShowDashboard  = true;
input int                InpArrowOffsetPips= 100;
input int                InpMtfArrowSize   = 3;
input int                InpCurArrowSize   = 1;

input group              "HTF Bar Preview"
input bool               InpShowHtfBar      = true;
input int                InpHtfBarShift     = 10;
input double             InpHtfBarScale     = 1.0;
input color              InpHtfBarBullColor = clrGreen;
input color              InpHtfBarBearColor = clrRed;
input bool               InpShowHtfLines    = true;
input color              InpHtfLineColor    = clrGray;
input ENUM_LINE_STYLE    InpHtfLineStyle    = STYLE_DOT;

input group              "Alert Settings"
input bool               InpEnableAlerts   = true;
input bool               InpEnableSound    = true;
input bool               InpEnableMail     = false;
input bool               InpEnablePush     = true;
input string             InpSoundFinal     = "alert.wav";
input string             InpSoundPossible  = "request.wav";

double MtfMaBuffer[];
double MtfColorBuffer[];
double CurrentMaBuffer[];
double CurrentColorBuffer[];

ENUM_TIMEFRAMES htf_TimeFrame;
bool            isMtfMode;

#define HMA_PREFIX "HMA_"
#define TIMER_MARKET_STATUS_NAME HMA_PREFIX "MarketStatus"
#define TIMER_CHART_OBJECT_NAME_1 HMA_PREFIX "CandleTimer1"
#define TIMER_CHART_OBJECT_NAME_2 HMA_PREFIX "CandleTimer2"
#define DASHBOARD_BOX_NAME_PREFIX HMA_PREFIX "Box_"
#define DASHBOARD_CHK_NAME_PREFIX HMA_PREFIX "Chk_"
#define DASHBOARD_CIRCLE_NAME HMA_PREFIX "Circle_"
#define MTF_ARROW_PREFIX HMA_PREFIX "MTF_Arrow_"
#define CUR_ARROW_PREFIX HMA_PREFIX "CUR_Arrow_"
#define HTF_BAR_BODY_NAME HMA_PREFIX "HtfBarBody"
#define HTF_BAR_WICK_NAME HMA_PREFIX "HtfBarWick"
#define HTF_LINE_HIGH_NAME HMA_PREFIX "HtfLineHigh"
#define HTF_LINE_LOW_NAME HMA_PREFIX "HtfLineLow"
#define HTF_LINE_OPEN_NAME HMA_PREFIX "HtfLineOpen"
#define HTF_LINE_CLOSE_NAME HMA_PREFIX "HtfLineClose"
#define BE_LINE_LONG_NAME HMA_PREFIX "BELineLong"
#define BE_LINE_SHORT_NAME HMA_PREFIX "BELineShort"
#define BE_LINE_NET_NAME HMA_PREFIX "BELineNet"
#define BE_PREVIEW_LINE_LONG_NAME HMA_PREFIX "BEPreviewLineLong"
#define BE_PREVIEW_LINE_SHORT_NAME HMA_PREFIX "BEPreviewLineShort"
#define INFO_LABEL_PREFIX HMA_PREFIX "InfoLabel_"

ENUM_TIMEFRAMES dashboard_timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
bool AlertEnabled[];
int PrevDashboardState[];
int PrevDashboardState_NonRepainting[];
datetime g_dashboardLastBarTimes[];

void CalculateHullMA(int rates_total, int start_pos, int period, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[], double &hma_buffer[], double &color_buffer[]);
string GetGlobalAlertVariableName(ENUM_TIMEFRAMES period);
void CreateDashboard();
void UpdateDashboardBox(int index);
int GetHmaState(ENUM_TIMEFRAMES tf);
int GetHmaStateNonRepainting(ENUM_TIMEFRAMES tf);
void DrawHtfBarPreview(int rates_total, const datetime &Time[], const double &High[], const double &Low[]);
void UpdateInfoPanel();
void CreateOrUpdateHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width);

int OnInit()
{
  SetIndexBuffer(0, MtfMaBuffer,      INDICATOR_DATA);
  SetIndexBuffer(1, MtfColorBuffer,   INDICATOR_COLOR_INDEX);
  SetIndexBuffer(2, CurrentMaBuffer,  INDICATOR_DATA);
  SetIndexBuffer(3, CurrentColorBuffer, INDICATOR_COLOR_INDEX);

  htf_TimeFrame = (InpTimeFrame == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpTimeFrame;
  isMtfMode     = (htf_TimeFrame != (ENUM_TIMEFRAMES)_Period);

  string shortName = "HMA(" + (string)InpHigherTfPeriod;
  if(isMtfMode)
    shortName += ", " + ShortPeriodString(htf_TimeFrame);
  if(InpCurrentTfPeriod > 0)
    shortName += " | " + (string)InpCurrentTfPeriod;
  shortName += ")";
  IndicatorSetString(INDICATOR_SHORTNAME, shortName);

  int num_timeframes = ArraySize(dashboard_timeframes);
  ArrayResize(AlertEnabled, num_timeframes);
  ArrayResize(PrevDashboardState, num_timeframes);
  ArrayResize(PrevDashboardState_NonRepainting, num_timeframes);
  ArrayResize(g_dashboardLastBarTimes, num_timeframes);
  ArrayInitialize(g_dashboardLastBarTimes, 0);
  ArrayInitialize(PrevDashboardState_NonRepainting, -2);


  for(int i = 0; i < num_timeframes; i++)
  {
    string gv_name = GetGlobalAlertVariableName(dashboard_timeframes[i]);
    AlertEnabled[i] = GlobalVariableCheck(gv_name) ? (bool)GlobalVariableGet(gv_name) : false;
    PrevDashboardState[i] = -2;
  }
  
  if(InpShowDashboard)
  {
      CreateDashboard();
  }
  
  EventSetTimer(1);
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  EventKillTimer();
  ObjectsDeleteAll(0, HMA_PREFIX);
  ChartRedraw();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id != CHARTEVENT_OBJECT_CLICK) return;

    if(InpShowDashboard)
    {
        string prefix = DASHBOARD_CHK_NAME_PREFIX;
        int prefix_len = StringLen(prefix);

        if(StringSubstr(sparam, 0, prefix_len) == prefix)
        {
            int index = (int)StringToInteger(StringSubstr(sparam, prefix_len));
            if(index >= 0 && index < ArraySize(dashboard_timeframes))
            {
                AlertEnabled[index] = !AlertEnabled[index];
                GlobalVariableSet(GetGlobalAlertVariableName(dashboard_timeframes[index]), AlertEnabled[index]);
                UpdateDashboardBox(index);
                ChartRedraw();
                return;
            }
        }

        prefix = DASHBOARD_BOX_NAME_PREFIX;
        prefix_len = StringLen(prefix);
        if(StringSubstr(sparam, 0, prefix_len) == prefix)
        {
            int index = (int)StringToInteger(StringSubstr(sparam, prefix_len));
            if(index >= 0 && index < ArraySize(dashboard_timeframes))
            {
                ChartSetSymbolPeriod(0, _Symbol, dashboard_timeframes[index]);
                return;
            }
        }
    }
}

void OnTimer()
{
  if(InpShowDashboard)
  {
    UpdateDashboard();
  }
  UpdateInfoPanel();
  ChartRedraw();
}

void UpdateInfoPanel()
{
    int y_pos = InpShowDashboard ? 80 : 40;
    int y_pos_offset = 40;
    int x_pos = 100;
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    long time_current = TimeCurrent();
    string market_status_text;
    color market_status_color;
    int trading_status = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
    
    switch(trading_status)
    {
        case SYMBOL_TRADE_MODE_DISABLED:
            market_status_text = "Market Closed";
            market_status_color = clrRed;
            break;
        case SYMBOL_TRADE_MODE_CLOSEONLY:
            market_status_text = "Market Close Only";
            market_status_color = clrOrange;
            break;
        case SYMBOL_TRADE_MODE_FULL:
            market_status_text = "Market Open";
            market_status_color = clrGreen;
            break;
        default:
            market_status_text = "Market Status Unknown";
            market_status_color = clrGray;
            break;
    }
    
    ObjectCreate(0, TIMER_MARKET_STATUS_NAME, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, TIMER_MARKET_STATUS_NAME, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, TIMER_MARKET_STATUS_NAME, OBJPROP_XDISTANCE, x_pos);
    ObjectSetInteger(0, TIMER_MARKET_STATUS_NAME, OBJPROP_YDISTANCE, y_pos);
    ObjectSetInteger(0, TIMER_MARKET_STATUS_NAME, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    
    // Calculate live spread
    int current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    ObjectSetString(0, TIMER_MARKET_STATUS_NAME, OBJPROP_TEXT, market_status_text + " (Spread: " + IntegerToString(current_spread) + ")");
    ObjectSetInteger(0, TIMER_MARKET_STATUS_NAME, OBJPROP_COLOR, market_status_color);
    y_pos += y_pos_offset;

    long chart_period_sec = PeriodSeconds();
    long time_to_chart_close = chart_period_sec > 0 ? chart_period_sec - (time_current % chart_period_sec) : 0;
    ObjectCreate(0, TIMER_CHART_OBJECT_NAME_1, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_1, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_1, OBJPROP_XDISTANCE, x_pos);
    ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_1, OBJPROP_YDISTANCE, y_pos);
    ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_1, OBJPROP_ANCHOR, ANCHOR_RIGHT);
    ObjectSetString(0, TIMER_CHART_OBJECT_NAME_1, OBJPROP_TEXT, ShortPeriodString((ENUM_TIMEFRAMES)_Period) + " Close: " + TimeToString(time_to_chart_close, TIME_MINUTES|TIME_SECONDS));
    ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_1, OBJPROP_COLOR, clrWhite);
    y_pos += y_pos_offset;
    
    ObjectDelete(0, TIMER_CHART_OBJECT_NAME_2);
    if(isMtfMode)
    {
      long mtf_period_sec = PeriodSeconds(htf_TimeFrame);
      long time_to_mtf_close = mtf_period_sec > 0 ? mtf_period_sec - (time_current % mtf_period_sec) : 0;
      ObjectCreate(0, TIMER_CHART_OBJECT_NAME_2, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_2, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_2, OBJPROP_XDISTANCE, x_pos);
      ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_2, OBJPROP_YDISTANCE, y_pos);
      ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_2, OBJPROP_ANCHOR, ANCHOR_RIGHT);
      ObjectSetString(0, TIMER_CHART_OBJECT_NAME_2, OBJPROP_TEXT, ShortPeriodString(htf_TimeFrame) + " Close: " + TimeToString(time_to_mtf_close, TIME_MINUTES|TIME_SECONDS));
      ObjectSetInteger(0, TIMER_CHART_OBJECT_NAME_2, OBJPROP_COLOR, clrWhite);
      y_pos += y_pos_offset;
    }

    double long_total_price_volume = 0, long_total_volume = 0, long_pnl = 0;
    int long_trades = 0;
    double short_total_price_volume = 0, short_total_volume = 0, short_pnl = 0;
    int short_trades = 0;
    
    double preview_long_total_price_volume = 0, preview_long_total_volume = 0;
    int preview_long_orders = 0;
    double preview_short_total_price_volume = 0, preview_short_total_volume = 0;
    int preview_short_orders = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                long_total_price_volume += open_price * volume;
                long_total_volume += volume;
                long_pnl += current_profit;
                long_trades++;
            }
            else
            {
                short_total_price_volume += open_price * volume;
                short_total_volume += volume;
                short_pnl += current_profit;
                short_trades++;
            }
        }
    }
    
    preview_long_total_price_volume = long_total_price_volume;
    preview_long_total_volume = long_total_volume;
    preview_short_total_price_volume = short_total_price_volume;
    preview_short_total_volume = short_total_volume;

    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket) && OrderGetString(ORDER_SYMBOL) == _Symbol)
        {
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type >= ORDER_TYPE_BUY_LIMIT && type <= ORDER_TYPE_SELL_STOP)
            {
                double volume = OrderGetDouble(ORDER_VOLUME_INITIAL);
                double open_price = OrderGetDouble(ORDER_PRICE_OPEN);
                
                if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP)
                {
                    preview_long_total_price_volume += open_price * volume;
                    preview_long_total_volume += volume;
                    preview_long_orders++;
                }
                else if(type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP)
                {
                    preview_short_total_price_volume += open_price * volume;
                    preview_short_total_volume += volume;
                    preview_short_orders++;
                }
            }
        }
    }
    
    ObjectDelete(0, BE_LINE_LONG_NAME);
    ObjectDelete(0, INFO_LABEL_PREFIX + "Long");
    if(long_total_volume > 0)
    {
        double be_price = NormalizeDouble(long_total_price_volume / long_total_volume, digits);
        string label = StringFormat("Long BE: %.*f | PnL: %.2f | Vol: %.2f | Trades: %d", digits, be_price, long_pnl, long_total_volume, long_trades);
        CreateOrUpdateHLine(BE_LINE_LONG_NAME, be_price, clrDodgerBlue, STYLE_SOLID, 2);
        ObjectCreate(0, INFO_LABEL_PREFIX + "Long", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Long", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Long", OBJPROP_XDISTANCE, x_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Long", OBJPROP_YDISTANCE, y_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Long", OBJPROP_ANCHOR, ANCHOR_RIGHT);
        ObjectSetString(0, INFO_LABEL_PREFIX + "Long", OBJPROP_TEXT, label);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Long", OBJPROP_COLOR, clrDodgerBlue);
        y_pos += y_pos_offset;
    }

    ObjectDelete(0, BE_LINE_SHORT_NAME);
    ObjectDelete(0, INFO_LABEL_PREFIX + "Short");
    if(short_total_volume > 0)
    {
        double be_price = NormalizeDouble(short_total_price_volume / short_total_volume, digits);
        string label = StringFormat("Short BE: %.*f | PnL: %.2f | Vol: %.2f | Trades: %d", digits, be_price, short_pnl, short_total_volume, short_trades);
        CreateOrUpdateHLine(BE_LINE_SHORT_NAME, be_price, clrOrangeRed, STYLE_SOLID, 2);
        ObjectCreate(0, INFO_LABEL_PREFIX + "Short", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Short", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Short", OBJPROP_XDISTANCE, x_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Short", OBJPROP_YDISTANCE, y_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Short", OBJPROP_ANCHOR, ANCHOR_RIGHT);
        ObjectSetString(0, INFO_LABEL_PREFIX + "Short", OBJPROP_TEXT, label);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "Short", OBJPROP_COLOR, clrOrangeRed);
        y_pos += y_pos_offset;
    }

    ObjectDelete(0, BE_LINE_NET_NAME);
    ObjectDelete(0, INFO_LABEL_PREFIX + "Net");
    if(long_total_volume > 0 && short_total_volume > 0)
    {
        double net_volume = long_total_volume - short_total_volume;
        if(MathAbs(net_volume) > 0.00001)
        {
             double be_price = NormalizeDouble((long_total_price_volume - short_total_price_volume) / net_volume, digits);
             string label = StringFormat("Net BE: %.*f", digits, be_price);
             CreateOrUpdateHLine(BE_LINE_NET_NAME, be_price, clrGold, STYLE_SOLID, 2);
             ObjectCreate(0, INFO_LABEL_PREFIX + "Net", OBJ_LABEL, 0, 0, 0);
             ObjectSetInteger(0, INFO_LABEL_PREFIX + "Net", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
             ObjectSetInteger(0, INFO_LABEL_PREFIX + "Net", OBJPROP_XDISTANCE, x_pos);
             ObjectSetInteger(0, INFO_LABEL_PREFIX + "Net", OBJPROP_YDISTANCE, y_pos);
             ObjectSetInteger(0, INFO_LABEL_PREFIX + "Net", OBJPROP_ANCHOR, ANCHOR_RIGHT);
             ObjectSetString(0, INFO_LABEL_PREFIX + "Net", OBJPROP_TEXT, label);
             ObjectSetInteger(0, INFO_LABEL_PREFIX + "Net", OBJPROP_COLOR, clrGold);
             y_pos += y_pos_offset;
        }
    }
    
    ObjectDelete(0, BE_PREVIEW_LINE_LONG_NAME);
    ObjectDelete(0, INFO_LABEL_PREFIX + "PreviewLong");
    if(preview_long_total_volume > long_total_volume)
    {
        double be_price = NormalizeDouble(preview_long_total_price_volume / preview_long_total_volume, digits);
        string label = StringFormat("Preview Long BE: %.*f | Vol: %.2f | Trades: %d", digits, be_price, preview_long_total_volume, long_trades + preview_long_orders);
        CreateOrUpdateHLine(BE_PREVIEW_LINE_LONG_NAME, be_price, clrLightSkyBlue, STYLE_DASH, 1);
        ObjectCreate(0, INFO_LABEL_PREFIX + "PreviewLong", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewLong", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewLong", OBJPROP_XDISTANCE, x_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewLong", OBJPROP_YDISTANCE, y_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewLong", OBJPROP_ANCHOR, ANCHOR_RIGHT);
        ObjectSetString(0, INFO_LABEL_PREFIX + "PreviewLong", OBJPROP_TEXT, label);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewLong", OBJPROP_COLOR, clrLightSkyBlue);
        y_pos += y_pos_offset;
    }
    
    ObjectDelete(0, BE_PREVIEW_LINE_SHORT_NAME);
    ObjectDelete(0, INFO_LABEL_PREFIX + "PreviewShort");
    if(preview_short_total_volume > short_total_volume)
    {
        double be_price = NormalizeDouble(preview_short_total_price_volume / preview_short_total_volume, digits);
        string label = StringFormat("Preview Short BE: %.*f | Vol: %.2f | Trades: %d", digits, be_price, preview_short_total_volume, short_trades + preview_short_orders);
        CreateOrUpdateHLine(BE_PREVIEW_LINE_SHORT_NAME, be_price, clrTomato, STYLE_DASH, 1);
        ObjectCreate(0, INFO_LABEL_PREFIX + "PreviewShort", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewShort", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewShort", OBJPROP_XDISTANCE, x_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewShort", OBJPROP_YDISTANCE, y_pos);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewShort", OBJPROP_ANCHOR, ANCHOR_RIGHT);
        ObjectSetString(0, INFO_LABEL_PREFIX + "PreviewShort", OBJPROP_TEXT, label);
        ObjectSetInteger(0, INFO_LABEL_PREFIX + "PreviewShort", OBJPROP_COLOR, clrTomato);
    }
}

void CreateDashboard()
{
    int box_width = 90;
    int box_height = 20;
    int chk_width = 20;
    int start_y = 20;
    int inner_spacing = 1;
    int group_spacing = 8;
    int num_boxes = ArraySize(dashboard_timeframes);
    int x_pos = 100;

    for(int i = num_boxes - 1; i >= 0; i--)
    {
        ENUM_TIMEFRAMES tf = dashboard_timeframes[i];
        string box_obj_name = DASHBOARD_BOX_NAME_PREFIX + (string)i;
        string chk_obj_name = DASHBOARD_CHK_NAME_PREFIX + (string)i;
        int x_pos_box = x_pos + chk_width + inner_spacing;
        
        ObjectCreate(0, box_obj_name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, box_obj_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, box_obj_name, OBJPROP_XDISTANCE, x_pos_box);
        ObjectSetInteger(0, box_obj_name, OBJPROP_YDISTANCE, start_y);
        ObjectSetInteger(0, box_obj_name, OBJPROP_XSIZE, box_width);
        ObjectSetInteger(0, box_obj_name, OBJPROP_YSIZE, box_height);
        ObjectSetInteger(0, box_obj_name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, box_obj_name, OBJPROP_SELECTABLE, true);
        
        ObjectCreate(0, chk_obj_name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, chk_obj_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, chk_obj_name, OBJPROP_XDISTANCE, x_pos+40);
        ObjectSetInteger(0, chk_obj_name, OBJPROP_YDISTANCE, start_y-5);
        ObjectSetInteger(0, chk_obj_name, OBJPROP_XSIZE, chk_width+10);
        ObjectSetInteger(0, chk_obj_name, OBJPROP_YSIZE, box_height+10);
        ObjectSetString(0, chk_obj_name, OBJPROP_TEXT, "!");
        ObjectSetInteger(0, chk_obj_name, OBJPROP_BORDER_COLOR, clrDimGray);
        ObjectSetInteger(0, chk_obj_name, OBJPROP_SELECTABLE, true);
        
        if(tf == _Period)
        {
          ObjectCreate(0, DASHBOARD_CIRCLE_NAME, OBJ_RECTANGLE, 0, 0, 0);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_XDISTANCE, x_pos_box - chk_width - inner_spacing - 2);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_YDISTANCE, start_y - 2);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_XSIZE, box_width + chk_width + inner_spacing + 4);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_YSIZE, box_height + 4);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_COLOR, DeepSkyBlue);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_BACK, true);
          ObjectSetInteger(0, DASHBOARD_CIRCLE_NAME, OBJPROP_SELECTABLE, false);
        }
        
        x_pos += box_width + chk_width + inner_spacing + group_spacing + 40;
        UpdateDashboardBox(i);
    }
}

void UpdateDashboard()
{
    datetime time_arr[1];
    for(int i = 0; i < ArraySize(dashboard_timeframes); i++)
    {
        if(CopyTime(_Symbol, dashboard_timeframes[i], 0, 1, time_arr) > 0)
        {
            if(time_arr[0] > g_dashboardLastBarTimes[i])
            {
                g_dashboardLastBarTimes[i] = time_arr[0];
                UpdateDashboardBox(i);
            }
        }
    }
}

void UpdateDashboardBox(int index)
{
    ENUM_TIMEFRAMES tf = dashboard_timeframes[index];
    string box_obj_name = DASHBOARD_BOX_NAME_PREFIX + (string)index;
    string chk_obj_name = DASHBOARD_CHK_NAME_PREFIX + (string)index;

    int current_nonrepaint_state = GetHmaStateNonRepainting(tf);
    if(PrevDashboardState_NonRepainting[index] != -2 && PrevDashboardState_NonRepainting[index] != current_nonrepaint_state && AlertEnabled[index])
    {
        string direction = (current_nonrepaint_state == 0) ? "UP" : "DOWN";
        SendAlert("Final", tf, direction);
    }
    PrevDashboardState_NonRepainting[index] = current_nonrepaint_state;

    int current_visual_state = GetHmaState(tf);
    PrevDashboardState[index] = current_visual_state;

    color box_color;
    string box_text = ShortPeriodString(tf);
    int trend_dir = -1;
    switch(current_visual_state)
    {
        case 0: trend_dir = 0; break;
        case 1: trend_dir = 1; break;
        case 2: trend_dir = 0; box_text += " !"; break;
        case 3: trend_dir = 1; box_text += " !"; break;
        case 4: trend_dir = 0; box_text += " ?"; break;
        case 5: trend_dir = 1; box_text += " ?"; break;
    }

    box_color = (trend_dir == 0) ? DeepSkyBlue : (trend_dir == 1) ? Orange : clrGray;

    ObjectSetInteger(0, box_obj_name, OBJPROP_BGCOLOR, box_color);
    ObjectSetString(0, box_obj_name, OBJPROP_TEXT, box_text);
    ObjectSetInteger(0, box_obj_name, OBJPROP_COLOR, clrWhite);

    color chk_bg_color = AlertEnabled[index] ? clrWhite : clrBlack;
    color chk_text_color = AlertEnabled[index] ? clrBlack : clrWhite;
    ObjectSetInteger(0, chk_obj_name, OBJPROP_BGCOLOR, chk_bg_color);
    ObjectSetInteger(0, chk_obj_name, OBJPROP_COLOR, chk_text_color);
}

int GetHmaState(ENUM_TIMEFRAMES tf)
{
    int bars_needed = InpHigherTfPeriod + (int)sqrt((double)InpHigherTfPeriod) + 10;
    MqlRates rates[];

    if(CopyRates(_Symbol, tf, 0, bars_needed, rates) < bars_needed) return -1;

    int total = ArraySize(rates);
    ArraySetAsSeries(rates, false);
    
    double hma_buffer[], color_buffer[];
    ArrayResize(hma_buffer, total); ArrayResize(color_buffer, total);
    double open[], high[], low[], close[];
    ArrayResize(open, total); ArrayResize(high, total); ArrayResize(low, total); ArrayResize(close, total);

    for(int i = 0; i < total; i++) { open[i] = rates[i].open; high[i] = rates[i].high; low[i] = rates[i].low; close[i] = rates[i].close; }

    CalculateHullMA(total, 0, InpHigherTfPeriod, InpPrice, open, high, low, close, hma_buffer, color_buffer);

    int last = total - 1;
    if(last < 3 || hma_buffer[last] == EMPTY_VALUE || hma_buffer[last-3] == EMPTY_VALUE) return -1;

    int dir_curr  = (hma_buffer[last] > hma_buffer[last-1]) ? 0 : 1;
    int dir_prev1 = (hma_buffer[last-1] > hma_buffer[last-2]) ? 0 : 1;
    int dir_prev2 = (hma_buffer[last-2] > hma_buffer[last-3]) ? 0 : 1;

    if(dir_curr != dir_prev1) return (dir_curr == 0) ? 4 : 5;
    if(dir_prev1 != dir_prev2) return (dir_curr == 0) ? 2 : 3;
    return (dir_curr == 0) ? 0 : 1;
}

int GetHmaStateNonRepainting(ENUM_TIMEFRAMES tf)
{
    int bars_needed = InpHigherTfPeriod + (int)sqrt((double)InpHigherTfPeriod) + 10;
    MqlRates rates[];

    if(CopyRates(_Symbol, tf, 0, bars_needed, rates) < bars_needed) return -1;

    int total = ArraySize(rates);
    if(total < 4) return -1;
    ArraySetAsSeries(rates, false);
    
    double hma_buffer[], color_buffer[];
    ArrayResize(hma_buffer, total); ArrayResize(color_buffer, total);
    double open[], high[], low[], close[];
    ArrayResize(open, total); ArrayResize(high, total); ArrayResize(low, total); ArrayResize(close, total);

    for(int i = 0; i < total; i++) { open[i] = rates[i].open; high[i] = rates[i].high; low[i] = rates[i].low; close[i] = rates[i].close; }

    CalculateHullMA(total, 0, InpHigherTfPeriod, InpPrice, open, high, low, close, hma_buffer, color_buffer);

    int last_closed = total - 2;
    if(last_closed < 1 || hma_buffer[last_closed] == EMPTY_VALUE || hma_buffer[last_closed-1] == EMPTY_VALUE) return -1;

    return (hma_buffer[last_closed] > hma_buffer[last_closed-1]) ? 0 : 1;
}


int OnCalculate(const int rates_total, const int prev_calculated, const datetime &Time[],
                const double &Open[], const double &High[], const double &Low[], const double &Close[],
                const long &TickVolume[], const long &Volume[], const int &Spread[])
{
  if(rates_total < 3) return 0;
  int start_pos = prev_calculated > 1 ? prev_calculated - 1 : 0;
  
  if(isMtfMode)
  {
    int lookback_needed_for_hma = InpHigherTfPeriod + (int)round(sqrt((double)InpHigherTfPeriod)) + 2;
    int htf_bars_to_copy = rates_total * 2; 
    MqlRates htf_rates[];
    if(CopyRates(_Symbol, htf_TimeFrame, 0, htf_bars_to_copy, htf_rates) >= lookback_needed_for_hma)
    {
      int htf_total = ArraySize(htf_rates);
      ArraySetAsSeries(htf_rates, false); 

      double htf_open[], htf_high[], htf_low[], htf_close[], htf_hma_values[], htf_color_values[];
      datetime htf_times[];
      ArrayResize(htf_open, htf_total); ArrayResize(htf_high, htf_total); ArrayResize(htf_low, htf_total); ArrayResize(htf_close, htf_total);
      ArrayResize(htf_hma_values, htf_total); ArrayResize(htf_color_values, htf_total);
      ArrayResize(htf_times, htf_total);

      for(int i = 0; i < htf_total; i++) {
        htf_open[i]  = htf_rates[i].open; htf_high[i]  = htf_rates[i].high;
        htf_low[i]   = htf_rates[i].low; htf_close[i] = htf_rates[i].close;
        htf_times[i] = htf_rates[i].time;
      }

      CalculateHullMA(htf_total, 0, InpHigherTfPeriod, InpPrice, htf_open, htf_high, htf_low, htf_close, htf_hma_values, htf_color_values);
      
      int htf_indexes[];
      ArrayResize(htf_indexes, rates_total);
      for(int i=0; i < rates_total; i++)
      {
         int htf_idx = ArrayBsearch(htf_times, Time[i]);
         if(htf_idx < 0) htf_idx = -htf_idx - 2;
         htf_indexes[i] = htf_idx;

         if(htf_idx >= 0 && htf_idx < htf_total) {
           MtfMaBuffer[i] = htf_hma_values[htf_idx];
           MtfColorBuffer[i] = htf_color_values[htf_idx];
         } else {
           MtfMaBuffer[i] = EMPTY_VALUE;
           MtfColorBuffer[i] = EMPTY_VALUE;
         }
      }

      for(int i = start_pos; i < rates_total; i++) {
        if (i < 1) continue;
        int htf_idx_curr = htf_indexes[i];
        int htf_idx_prev = htf_indexes[i-1];

        if (htf_idx_curr > htf_idx_prev)
        {
            if(htf_idx_prev > 0)
            {
                 if(htf_color_values[htf_idx_prev] != htf_color_values[htf_idx_prev - 1])
                 {
                     string objName = MTF_ARROW_PREFIX + (string)Time[i-1];
                     if(htf_color_values[htf_idx_prev] == 0)
                     {
                         ObjectCreate(0, objName, OBJ_ARROW_UP, 0, Time[i-1], Low[i-1] - InpArrowOffsetPips * _Point);
                         ObjectSetInteger(0, objName, OBJPROP_COLOR, DeepSkyBlue);
                         ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpMtfArrowSize);
                     }
                     else
                     {
                         ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, Time[i-1], High[i-1] + InpArrowOffsetPips * _Point);
                         ObjectSetInteger(0, objName, OBJPROP_COLOR, Orange);
                         ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpMtfArrowSize);
                     }
                 }
            }
        }
      }
    }
  }

  if(InpCurrentTfPeriod > 0)
  {
      CalculateHullMA(rates_total, start_pos, InpCurrentTfPeriod, InpPrice, Open, High, Low, Close, CurrentMaBuffer, CurrentColorBuffer);
      
      for(int i = start_pos; i < rates_total; i++) {
          if(i > 1 && CurrentColorBuffer[i-1] != CurrentColorBuffer[i-2]) {
              bool isMtfTrendUp = !isMtfMode || (MtfColorBuffer[i-1] == 0);
              bool isMtfTrendDown = !isMtfMode || (MtfColorBuffer[i-1] == 1);
              
              if(CurrentColorBuffer[i-1] == 0 && isMtfTrendUp) {
                  string objName = CUR_ARROW_PREFIX + (string)Time[i-1];
                  ObjectCreate(0, objName, OBJ_ARROW_UP, 0, Time[i-1], Low[i-1] - InpArrowOffsetPips * _Point * 0.5);
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, DeepSkyBlue);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpCurArrowSize);
              } else if(CurrentColorBuffer[i-1] == 1 && isMtfTrendDown) {
                  string objName = CUR_ARROW_PREFIX + (string)Time[i-1];
                  ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, Time[i-1], High[i-1] + InpArrowOffsetPips * _Point * 0.5);
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, Orange);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, InpCurArrowSize);
              }
          }
      }
  } else {
      if(prev_calculated == 0) ObjectsDeleteAll(0, CUR_ARROW_PREFIX);
      ArrayInitialize(CurrentMaBuffer, EMPTY_VALUE); 
      ArrayInitialize(CurrentColorBuffer, EMPTY_VALUE);
  }
  
  DrawHtfBarPreview(rates_total, Time, High, Low);

  return(rates_total);
}

void CalculateHullMA(int rates_total, int start_pos, int period, ENUM_APPLIED_PRICE price_type,
                     const double &open[], const double &high[], const double &low[], const double &close[],
                     double &hma_buffer[], double &color_buffer[])
{
    if (period <= 1 || rates_total == 0) return;
    int hma_period = period;
    int half_period = (int)round(hma_period / 2.0);
    int sqrt_period = (int)round(sqrt((double)hma_period));

    double prices[]; ArrayResize(prices, rates_total);
    for(int i = 0; i < rates_total; i++) prices[i] = SelectPrice(price_type, i, open, high, low, close);

    double wma_half[], wma_full[], raw_hma[];
    ArrayResize(wma_half, rates_total); ArrayResize(wma_full, rates_total); ArrayResize(raw_hma, rates_total);

    CalculateWMA(half_period, rates_total, 0, prices, wma_half);
    CalculateWMA(hma_period, rates_total, 0, prices, wma_full);

    for(int i = 0; i < rates_total; i++) {
        if(wma_half[i] == EMPTY_VALUE || wma_full[i] == EMPTY_VALUE) raw_hma[i] = EMPTY_VALUE;
        else raw_hma[i] = 2.0 * wma_half[i] - wma_full[i];
    }

    CalculateWMA(sqrt_period, rates_total, 0, raw_hma, hma_buffer);
    
    if(rates_total > 0) color_buffer[0] = 0;
    for(int i = 1; i < rates_total; i++) {
        if(hma_buffer[i] != EMPTY_VALUE && hma_buffer[i-1] != EMPTY_VALUE) {
            if(hma_buffer[i] > hma_buffer[i-1]) color_buffer[i] = 0;
            else if (hma_buffer[i] < hma_buffer[i-1]) color_buffer[i] = 1;
            else color_buffer[i] = color_buffer[i-1];
        } else {
           color_buffer[i] = color_buffer[i-1];
        }
    }
}

void CalculateWMA(int period, int rates_total, int start_pos, const double &source[], double &dest[])
{
  if(period <= 0) return;
  double sum_weights = period * (period + 1) / 2.0;
  if(sum_weights == 0) return;

  for(int i = start_pos; i < rates_total; i++) {
    if(i < period - 1) { dest[i] = EMPTY_VALUE; continue; }
    double sum_values = 0;
    for(int k = 0; k < period; k++) {
      if(source[i-k] == EMPTY_VALUE) {
         sum_values = EMPTY_VALUE;
         break;
      }
      sum_values += source[i - k] * (period - k);
    }
    if(sum_values != EMPTY_VALUE)
       dest[i] = sum_values / sum_weights;
    else
       dest[i] = EMPTY_VALUE;
  }
}

double SelectPrice(ENUM_APPLIED_PRICE type, int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
  switch(type)
  {
    case PRICE_CLOSE:    return(close[i]);
    case PRICE_OPEN:     return(open[i]);
    case PRICE_HIGH:     return(high[i]);
    case PRICE_LOW:      return(low[i]);
    case PRICE_MEDIAN:   return((high[i] + low[i]) / 2.0);
    case PRICE_TYPICAL:  return((high[i] + low[i] + close[i]) / 3.0);
    case PRICE_WEIGHTED: return((high[i] + low[i] + 2*close[i]) / 4.0);
    default:             return(close[i]);
  }
}

void DrawHtfBarPreview(int rates_total, const datetime &Time[], const double &High[], const double &Low[])
{
    string line_names[] = {HTF_BAR_BODY_NAME, HTF_BAR_WICK_NAME, HTF_LINE_HIGH_NAME, HTF_LINE_LOW_NAME, HTF_LINE_OPEN_NAME, HTF_LINE_CLOSE_NAME};
    if(!isMtfMode || (!InpShowHtfBar && !InpShowHtfLines))
    {
        for(int i=0; i < ArraySize(line_names); i++) ObjectDelete(0, line_names[i]);
        return;
    }
    if(!InpShowHtfBar) { ObjectDelete(0, HTF_BAR_BODY_NAME); ObjectDelete(0, HTF_BAR_WICK_NAME); }
    if(!InpShowHtfLines) { ObjectDelete(0, HTF_LINE_HIGH_NAME); ObjectDelete(0, HTF_LINE_LOW_NAME); ObjectDelete(0, HTF_LINE_OPEN_NAME); ObjectDelete(0, HTF_LINE_CLOSE_NAME); }
    
    if(rates_total < 2) return;

    MqlRates htf_rates[1];
    if(CopyRates(_Symbol, htf_TimeFrame, 0, 1, htf_rates) < 1) return;

    long period_seconds = PeriodSeconds();
    if(period_seconds == 0) return;

    datetime htf_start_time = htf_rates[0].time;
    double htf_open_true  = htf_rates[0].open;
    double htf_high_true  = htf_rates[0].high;
    double htf_low_true   = htf_rates[0].low;
    double htf_close_true = htf_rates[0].close;

    datetime last_bar_time = Time[rates_total - 1];
    datetime x_dest_time   = (datetime)((long)last_bar_time + (long)InpHtfBarShift * period_seconds);
    datetime x_body_end    = (datetime)((long)x_dest_time + (long)period_seconds * 2);
    datetime x_wick_time   = (datetime)((long)x_dest_time + ((long)x_body_end - (long)x_dest_time) / 2);

    datetime time_open = htf_start_time;
    datetime time_high = htf_start_time;
    datetime time_low  = htf_start_time;
    datetime time_close = last_bar_time;
    
    double max_h = -DBL_MAX;
    double min_l = DBL_MAX;

    for(int i = rates_total - 1; i >= 0; i--)
    {
        if(Time[i] < htf_start_time) break;
        if(High[i] > max_h) { max_h = High[i]; time_high = Time[i]; }
        if(Low[i] < min_l) { min_l = Low[i]; time_low = Time[i]; }
    }
    
    if(InpShowHtfBar)
    {
        double mid_point = (htf_high_true + htf_low_true) / 2.0;
        double htf_high_scaled  = mid_point + (htf_high_true - mid_point) * InpHtfBarScale;
        double htf_low_scaled   = mid_point + (htf_low_true - mid_point) * InpHtfBarScale;
        double htf_open_scaled  = mid_point + (htf_open_true - mid_point) * InpHtfBarScale;
        double htf_close_scaled = mid_point + (htf_close_true - mid_point) * InpHtfBarScale;
        color bar_color = (htf_close_true >= htf_open_true) ? InpHtfBarBullColor : InpHtfBarBearColor;

        if(ObjectFind(0, HTF_BAR_WICK_NAME) < 0) {
            ObjectCreate(0, HTF_BAR_WICK_NAME, OBJ_TREND, 0, 0, 0);
            ObjectSetInteger(0, HTF_BAR_WICK_NAME, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, HTF_BAR_WICK_NAME, OBJPROP_BACK, true);
            ObjectSetInteger(0, HTF_BAR_WICK_NAME, OBJPROP_SELECTABLE, false);
        }
        ObjectMove(0, HTF_BAR_WICK_NAME, 0, x_wick_time, htf_high_scaled);
        ObjectMove(0, HTF_BAR_WICK_NAME, 1, x_wick_time, htf_low_scaled);
        ObjectSetInteger(0, HTF_BAR_WICK_NAME, OBJPROP_COLOR, bar_color);

        if(ObjectFind(0, HTF_BAR_BODY_NAME) < 0) {
            ObjectCreate(0, HTF_BAR_BODY_NAME, OBJ_RECTANGLE, 0, 0, 0);
            ObjectSetInteger(0, HTF_BAR_BODY_NAME, OBJPROP_FILL, true);
            ObjectSetInteger(0, HTF_BAR_BODY_NAME, OBJPROP_BACK, true);
            ObjectSetInteger(0, HTF_BAR_BODY_NAME, OBJPROP_SELECTABLE, false);
        }
        ObjectMove(0, HTF_BAR_BODY_NAME, 0, x_dest_time, htf_open_scaled);
        ObjectMove(0, HTF_BAR_BODY_NAME, 1, x_body_end, htf_close_scaled);
        ObjectSetInteger(0, HTF_BAR_BODY_NAME, OBJPROP_COLOR, bar_color);
        ObjectSetInteger(0, HTF_BAR_BODY_NAME, OBJPROP_BGCOLOR, bar_color);
    }
    
    if(InpShowHtfLines)
    {
       string names[] = {HTF_LINE_HIGH_NAME, HTF_LINE_LOW_NAME, HTF_LINE_OPEN_NAME, HTF_LINE_CLOSE_NAME};
       double prices[] = {htf_high_true, htf_low_true, htf_open_true, htf_close_true};
       datetime times[] = {time_high, time_low, time_open, time_close};
       
       for(int i=0; i<4; i++)
       {
           if(ObjectFind(0, names[i]) < 0) {
               ObjectCreate(0, names[i], OBJ_TREND, 0, 0, 0);
               ObjectSetInteger(0, names[i], OBJPROP_STYLE, InpHtfLineStyle);
               ObjectSetInteger(0, names[i], OBJPROP_COLOR, InpHtfLineColor);
               ObjectSetInteger(0, names[i], OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, names[i], OBJPROP_BACK, true);
               ObjectSetInteger(0, names[i], OBJPROP_SELECTABLE, false);
           }
           ObjectMove(0, names[i], 0, times[i], prices[i]);
           ObjectMove(0, names[i], 1, x_dest_time, prices[i]);
       }
    }
}


string ShortPeriodString(ENUM_TIMEFRAMES period)
{
  string str = EnumToString(period);
  StringReplace(str, "PERIOD_", "");
  return(str);
}

string GetGlobalAlertVariableName(ENUM_TIMEFRAMES period)
{
  return HMA_PREFIX + "Alert_" + "_" + EnumToString(period);
}

void SendAlert(string signal_type, ENUM_TIMEFRAMES tf, string direction)
{
    string message = StringFormat("HMA_MTF (%s, %s): %s HMA switching %s on TF %s",
                                  _Symbol,
                                  ShortPeriodString((ENUM_TIMEFRAMES)_Period),
                                  signal_type,
                                  direction,
                                  ShortPeriodString(tf));

    string sound_to_play = (signal_type == "Final") ? InpSoundFinal : InpSoundPossible;

    if(InpEnableAlerts) Alert(message);
    if(InpEnableSound) PlaySound(sound_to_play);
    if(InpEnableMail) SendMail("HMA Alert", message);
    if(InpEnablePush) SendNotification(message);
}


void CreateOrUpdateHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}