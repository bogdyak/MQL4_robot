//+------------------------------------------------------------------+
//|                                                    DayT v1.9.mq4 |
//|                                               Bogdan Sizov       |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Bogdan Sizov"
#property version   "1.8"
#property description "DayT expert advisor"

#define MAGICMA  6666666

//--- Inputs
input double RiskFactor    =10;
input double StopLevel     =525;
input double TakeLevel     =525;
input bool   TrailStop     =true;
input bool   IfProfit      =true;
input bool   RealTime      =true;
input bool   PreClose      =true;
input double TakePerc      =3.3;
input bool   UnLoss        =false;
input int    MovingPeriod =8;
//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- check for history and trading
   if(Bars<100 || IsTradeAllowed()==false) return;
 
   CheckForOpen(); 
   if(TrailStop) TrailStopOrders();
   if(UnLoss) UnLossOrders();
   if(PreClose) PreCloseOrders(); 
   
  }

//+------------------------------------------------------------------+
//| Calculate open positions                                         |
//+------------------------------------------------------------------+
int CalculateCurrentOrders(string symbol)
  {
   int buys=0,sells=0;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MAGICMA)
        {
         if(OrderType()==OP_BUY)  buys++;
         if(OrderType()==OP_SELL) sells++;
        }
     }
//--- return orders volume
   if(buys>0) return(buys);
   else       return(-sells);
  }
  
//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double LotsOptimized()
  {
   double lot; int leverage=AccountInfoInteger(ACCOUNT_LEVERAGE);
               int lotsize=MarketInfo(Symbol(),MODE_LOTSIZE);
//--- select lot size
   lot=NormalizeDouble(AccountFreeMargin()*(RiskFactor/100)/lotsize,2);
   Print("Calculated lot size="+DoubleToString(lot,2));
//--- return lot size
   double lotstep=MarketInfo(Symbol(),MODE_LOTSTEP);
//--- round lot size if need
   if (MathMod(lot,lotstep)!=0) lot=MathFloor(lot);
//--- check minimal trade lvl
   double minlot=MarketInfo(Symbol(),MODE_MINLOT);
   if(lot<minlot) lot=minlot;
   return(lot);
  }
  
//+------------------------------------------------------------------+
//| Check for open order conditions                                  |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   int res=0; double SL=0, TP=0;
//--- go trading only for first tiks of new bar
   if(Volume[0]>1) return;
   double ma=iMA(NULL,0,MovingPeriod,0,MODE_SMMA,PRICE_MEDIAN,0);
//--- buy conditions
   if((Open[1]<Close[1]) && Ask>ma)
     {TP=NormalizeDouble(Ask+TakeLevel*Point,Digits); SL=NormalizeDouble(Ask-StopLevel*Point,Digits);
      res=OrderSend(Symbol(),OP_BUY,LotsOptimized(),Ask,3,SL,TP,"DayT",MAGICMA,0,RoyalBlue);
      return;}
   //--- sell conditions
   if((Open[1]>Close[1]) &&Bid<ma)
     {TP=NormalizeDouble(Bid-TakeLevel*Point,Digits); SL=NormalizeDouble(Bid+StopLevel*Point,Digits);
      res=OrderSend(Symbol(),OP_SELL,LotsOptimized(),Bid,3,SL,TP,"DayT",MAGICMA,0,OrangeRed);
      return;}

  }

//+------------------------------------------------------------------+
//| Trailing Stop procedure                                          |
//+------------------------------------------------------------------+     
void TrailStopOrders()
  {
   double minstop  =MarketInfo(Symbol(),MODE_STOPLEVEL)*MarketInfo(Symbol(),MODE_POINT);
   double lasthigh =iHigh(Symbol(),Period(),1);
   double lastlow  =iLow(Symbol(),Period(),1);
   
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      
      //--- check order time
      if(!RealTime) if(TimeCurrent()-OrderOpenTime()<PeriodSeconds(PERIOD_CURRENT)) continue;
      if(IfProfit) if(OrderProfit()<0) continue;
      
      if(OrderType()==OP_BUY && OrderStopLoss()<lastlow && Bid-lastlow>minstop)
        {//--- if we too far - set shortloss (modify SL to shortloss); else - we do nothing, just wait
         if(!OrderModify(OrderTicket(),OrderOpenPrice(),lastlow,OrderTakeProfit(),0,DarkOrchid))
           if(GetLastError()!=1) Print("Order #",OrderTicket()," SL to SHORTLOSS Modify error ",GetLastError());
         continue;}
         
      //--- if order type SELL
      if(OrderType()==OP_SELL && OrderStopLoss()>lasthigh && lasthigh-Ask>minstop)
        {//--- if we too far - set shortloss (modify SL to shortloss); else - we do nothing, just wait
         if(!OrderModify(OrderTicket(),OrderOpenPrice(),lasthigh,OrderTakeProfit(),0,DarkOrchid))
           if(GetLastError()!=1) Print("Order #",OrderTicket()," SL to SHORTLOSS Modify error ",GetLastError());
         continue;}
     }     
  }

//+------------------------------------------------------------------+
//| Unloss procedure                                                 |
//+------------------------------------------------------------------+     
void UnLossOrders()
  {
   double minstop =MarketInfo(Symbol(),MODE_STOPLEVEL)*MarketInfo(Symbol(),MODE_POINT);
   double param=0;
   
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      
      //--- check order time
      if(!RealTime) if(TimeCurrent()-OrderOpenTime()<PeriodSeconds(PERIOD_CURRENT)) continue;
      if(IfProfit) if(OrderProfit()<0) continue; 
      param =OrderOpenPrice();
      
      if(OrderType()==OP_BUY && OrderStopLoss()<param && Bid-param>minstop)
        {//--- modify SL to UNLOSS
         if(!OrderModify(OrderTicket(),OrderOpenPrice(),param,OrderTakeProfit(),0,Black))
           if(GetLastError()!=1) Print("Order #",OrderTicket()," SL to UNLOSS Modify error ",GetLastError());
         continue;}
         
      //--- if order type SELL
      if(OrderType()==OP_SELL && OrderStopLoss()>param && param-Ask>minstop)
        {//--- modify SL to UNLOSS
         if(!OrderModify(OrderTicket(),OrderOpenPrice(),param,OrderTakeProfit(),0,Black))
           if(GetLastError()!=1) Print("Order #",OrderTicket()," SL to UNLOSS Modify error ",GetLastError());
         continue;}
     }     
  }

//+------------------------------------------------------------------+
//| CloseOld procedure                                               |
//+------------------------------------------------------------------+     
void PreCloseOrders()
  {    
     for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderMagicNumber()!=MAGICMA || OrderSymbol()!=Symbol()) continue;
      
      //--- check order time && check flag
      if(!RealTime) if(TimeCurrent()-OrderOpenTime()<PeriodSeconds(PERIOD_CURRENT)) continue;
      if(IfProfit) if(OrderProfit()<AccountBalance()*TakePerc/100) continue;
      
      //--- check order type 
      if(OrderType()==OP_BUY)
        {if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Gold))
           Print("OrderClose error ",GetLastError()); continue;}
      if(OrderType()==OP_SELL)
        {if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Gold))
           Print("OrderClose error ",GetLastError()); continue;}
     }
  }
//+------------------------------------------------------------------+  