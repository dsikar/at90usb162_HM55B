#include <math.h> 

/*
Code 
*/

//// VARS
byte CLK_pin = 6;
byte EN_pin = 7;
byte DIN_pin = 8;
byte DOUT_pin = 10;
byte READOK_pin = 12;
byte W_pin = 13;
byte E_pin = 14;

int iRead = 0;

int X_Data = 0;
int Y_Data = 0;
float angle;

int iAvgCount = 1;
float fCalibrationAvg = 0;

//// FUNCTIONS

/*
// Calibration function
// Required for every HM55B device

void average_100_readings(float myangle)
{   
  if(iAvgCount==100){
    fCalibrationAvg /= 100;
    Serial.print("Angle average for 100 readings = ");
    Serial.print(fCalibrationAvg);
    Serial.print(" for angle ");
    Serial.print(myangle); 
    Serial.println("************** FINISHED AVERAGING ANGLE **************");
    iAvgCount = 0;
    fCalibrationAvg = 0;
  }
  else {
    fCalibrationAvg += myangle;
    iAvgCount++;
    Serial.print("Calibration count for angle ");
    Serial.print(myangle); 
    Serial.print(" = ");    
    Serial.print(iAvgCount);
    Serial.println("");
  }
}
*/

float adjusted(float myangle)
{
   // raw and offsets arrays moved out due to bug related to having to declared arrays in one function.
   // values now returned by functions, instead of direct reference to arrays.
   
   int iPaddedIndex = 17; 
   int index = 0;
   float offset = 0;
   for(index=iPaddedIndex;index>0;index--) if(myangle>=raw(index-1)) break;
   // do linear interpolation to obtain unknown offset for known angle
   offset = (myangle-raw(index-1))*(offsets(index)-offsets(index-1))/(raw(index)-raw(index-1))+offsets(index-1);
   // convert negative angle to generate a 360 degree scale
   return(myangle+offset<0?myangle+offset+360:myangle+offset);
}

float raw(int index)
{
    // 0riginal 16 calibration readings ~ -154, -120, -101, -89, -78, -64, -40, -2, 41, 66, 80, 91, 101, 112, 129, 158.
    // raw[0] = raw[16] - 360;
    // raw[17] = raw[1] + 360;
    float raw[18] = {-202, -154, -120, -101, -89, -78, -64, -40, -2, 41, 66, 80, 91, 101, 112, 129, 158, 206}; 
    return raw[index];
}

float offsets(int index)
{  
    // Original offsets -3.5, -15, -11.5, -1, 10.5, 19, 17.5, 2, -18.5, -21, -12.5, -1, 11.5, 23, 28.5, 22.
    // offsets[0] = offsets[16];
    // offsets[17] = offsets[1];
    float offsets[18] = {22, -3.5, -15, -11.5, -1, 10.5, 19, 17.5, 2, -18.5, -21, -12.5, -1, 11.5, 23, 28.5, 22, -3.5};
    return offsets[index];
}

void ShiftOut(int Value, int BitsCount) {
  for(int i = BitsCount; i >= 0; i--) {
    //delay(10);
    digitalWrite(CLK_pin, HIGH);
    if ((Value & 1 << i) == ( 1 << i)) {
      digitalWrite(DOUT_pin, HIGH);
      //Serial.print("1");
    }
    else {
      digitalWrite(DOUT_pin, LOW);
      //Serial.print("0");
    }
    digitalWrite(CLK_pin, LOW);
    delay(1);
  }
}

int ShiftIn(int BitsCount) {
  int ShiftIn_result;
    ShiftIn_result = 0;
    for(int i = BitsCount; i >= 0; i--) {
      digitalWrite(CLK_pin, HIGH);
      if (digitalRead(DIN_pin) == HIGH) {
        ShiftIn_result = (ShiftIn_result << 1) + 1; 
      }
      else {
        ShiftIn_result = (ShiftIn_result << 1) + 0;
      }
      digitalWrite(CLK_pin, LOW);
      delay(1);
    }

// below is difficult to understand:
// if bit 11 is Set the value is negative
// the representation of negative values you
// have to add B11111000 in the upper Byte of
// the integer.
// see: http://en.wikipedia.org/wiki/Two%27s_complement
  if ((ShiftIn_result & 1 << 11) == 1 << 11) {
    ShiftIn_result = (B11111000 << 8) | ShiftIn_result; 
  }
  return ShiftIn_result;
}

void HM55B_Reset() {
  digitalWrite(CLK_pin, LOW);
  digitalWrite(EN_pin, LOW);
  ShiftOut(B0000, 3);
  digitalWrite(EN_pin, HIGH);
}

void HM55B_StartMeasurementCommand() {
  digitalWrite(EN_pin, LOW);
  ShiftOut(B1000, 3);
  digitalWrite(EN_pin, HIGH);
}

int HM55B_ReadCommand() {
  
  int result = 0;
  
  digitalWrite(EN_pin, LOW);
  ShiftOut(B1100, 3);
  result = ShiftIn(3);
  return result;
}

void setup() {
  Serial.begin(9600);
  pinMode(EN_pin, OUTPUT);
  pinMode(CLK_pin, OUTPUT);
  pinMode(DIN_pin, INPUT);
  pinMode(DOUT_pin, OUTPUT);
  pinMode(READOK_pin, OUTPUT);
  pinMode(E_pin, OUTPUT);
  pinMode(W_pin, OUTPUT);

  
  HM55B_Reset();
}

void loop() {
  HM55B_StartMeasurementCommand();
  delay(40); // the data is 40ms later ready
  iRead = HM55B_ReadCommand();
 
  X_Data = ShiftIn(11); // Field strength in X
  Y_Data = ShiftIn(11); // and Y direction

  angle = 180 * (atan2(-1 * Y_Data , X_Data) / M_PI); // angle is atan( -y/x) !!!
  if(angle>=0){
    digitalWrite(W_pin, LOW);
    digitalWrite(E_pin, HIGH);
  }
  else{
    digitalWrite(W_pin, HIGH);
    digitalWrite(E_pin, LOW);    
  } 

  // send iAjustedAngle to requester
  
  int iAdjustedAngle = adjusted(angle);
  Serial.print("Raw angle = ");
  Serial.print(angle); // print angle
  Serial.print(", adjusted angle = ");
  Serial.print(iAdjustedAngle);
  Serial.println("");
  
  if(iRead != B1100) {
    digitalWrite(READOK_pin, LOW);  
  }
  else {
    digitalWrite(READOK_pin, HIGH);     
  }
  digitalWrite(EN_pin, HIGH);
}

