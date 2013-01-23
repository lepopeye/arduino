// Station meteo 
// version 2
// http://lepopeye.fr/doku.php/arduino_projet_meteo
// 23/01/2013

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <dht11.h>
#include <LiquidCrystal.h>
#include <Wire.h>
#include <Ethernet.h>
#include <SPI.h>
#include <Stdio.h>
#include <OneWire.h>

#define Binary 0
#define Hex 1

// Permet de compter les elements d'un tableau
#define ROW_COUNT(array)    (sizeof(array) / sizeof(*array))
#define COLUMN_COUNT(array) (sizeof(array) / (sizeof(**array) * ROW_COUNT(array)))

LiquidCrystal_I2C lcd(0x27,20,4);  // set the LCD address to 0x20 for a 16 chars and 2 line display

#define BMP085_ADDRESS 0x77  // I2C address of BMP085

const unsigned char OSS = 0;  // Oversampling Setting

dht11 DHT11;
char tampon[25];

// Calibration values
int ac1;
int ac2;
int ac3;
unsigned int ac4;
unsigned int ac5;
unsigned int ac6;
int b1;
int b2;
int mb;
int mc;
int md;
long b5;

// Variables capteur exterieur
OneWire  ds(9);  // l'entrée 8 de l'Arduino recevra
byte present = 0;
byte data[12];
byte addr[8];
int HighByte, LowByte, SignBit, Whole, bar, Fract, TReading, Tc_100, FWhole;

// Caractère speciaux ecran LCD
byte baisse[8] = {
  B00000,
  B00000,
  B10000,
  B01001,
  B00101,
  B00011,
  B01111,
};

byte augmente[8] = {
  B01111,
  B00011,
  B00101,
  B01001,
  B10000,
  B00000,
  B00000,
};

byte celsius[8] = {
  B10011,
  B00100,
  B00100,
  B00011,
  B00000,
  B00000,
  B00000,
  B00000,
};

byte maison[8] = {
  B00100,
  B01010,
  B10001,
  B11111,
  B10001,
  B10001,
  B10001,
  B11111,
};
byte pression[8] = {
  B00000,
  B00100,
  B00100,
  B00100,
  B01110,
  B00000,
  B01110,
  B00100,
};
byte reseau[8] = {
  B00000,
  B11111,
  B10001,
  B10001,
  B10101,
  B11001,
  B11111,
  B10000,
};


byte goutte[8] = {
  B00100,
  B00100,
  B00100,
  B01110,
  B01110,
  B11111,
  B11111,
  B01110,

};


byte thermometre[8] = {
  B00100,
  B01010,
  B01010,
  B01010,
  B01010,
  B10001,
  B01110,
};

int DHT11PIN = 2;
int pirPin = 8;
int lumiPin = A2; // pin for potentiometer


int mouvement = 0;
int lumiMap = 0;
short  temp_in, temp_out;
long  pressure;

//0:tempIn, 1:temp2In, 2:tempOut, 3:Humi, 4:pression, 5:lumi
//0 : live, 1 : min, 2 : max, 3 : old, 4 : borne_min, 5 : borne_max


long capteur[6][6] =  {
  {
    0, 99, 0,0 ,17, 23                  } 
  ,
  {
    0, 99, 0,0, 17, 23                  } 
  ,
  {
    0, 99, 0,0 ,10, 30                  } 
  ,
  {
    0, 99, 0,0, 40, 80                  } 
  ,
  {
    0, 999999, 0,0 ,1010, 1015                  } 
  ,
  {
    0, 100,0,0,0,0                  }
}
;

// LIVE -> 0:jour,1:mois,2:annee,3:heure,4:minute,5:seconde
// OLD -> 6:jour,7:mois,8:annee,9:heure,10:minute,11:seconde
byte time[12] = {
  0,0,0,0,0,0,0,0,0,0,0,0};

// Evolution -> 0:temp1In, 1:temp2In, 2:tempOut, 3:pression, 4:humidity
String evolu[] = {
  "=","=","=","=","=",};


byte i;
int lumi = 0;
int lcd_pos=8;
int compteur=0;
String toUrl;


/*******************************************************************************
 * Function Prototype
 *******************************************************************************/
unsigned int SerialNumRead (byte);
void SetTime();
void DisplayTime();


/*******************************************************************************
 * Global variables
 *******************************************************************************/
const int I2C_address = 0x68;  // I2C write address
byte    Second;     // Store second value
byte    Minute;     // Store minute value
byte    Hour;       // Store hour value
byte    Day;        // Store day value
byte    Date;       // Store date value
byte    Month;      // Store month value
byte    Year;       // Store year value

byte old_date;

/*******************************************************************************
 * Réseau
 *******************************************************************************/
byte mac[] = { 
  0x90,0xA2,0xDA,0x00,0x55,0x8D};  //Replace with your Ethernet shield MAC
byte ip[] = { 
  192,168,1,89};  //The Arduino device IP address
byte subnet[] = { 
  255,255,255,0};
byte gateway[] = { 
  192,168,1,1};
byte server[] = { 
  192,168,1,10 }; // Google IP

Client client(server, 80);



void setup()
{

  pinMode(pirPin, INPUT);
  pinMode(lumiPin, INPUT);

  Serial.begin(9600); //(Remove all 'Serial' commands if not needed)
  lcd.init(); // initialize the lcd
  lcd.backlight();
  lcd.cursor_on();
  lcd.blink_on();
  lcd.createChar(0, baisse);
  lcd.createChar(1, augmente);
  lcd.createChar(2, goutte);
  lcd.createChar(3, thermometre);
  lcd.createChar(4, pression);
  lcd.createChar(5, reseau);
  lcd.createChar(6, maison);
  lcd.clear();
  lcd.backlight();
  lcd.setCursor(0,0);
  lcd.cursor_off();
  lcd.blink_off();
  Wire.begin();
  bmp085Calibration();

  // *** Initialisation capteur extérieur ds18b20/
  if ( !ds.search(addr)) {
    lcd.clear();
    lcd.setCursor(0,1);
    lcd.print("Erreur addr ds18b20");
    delay(1000);
    ds.reset_search();
    return;
  }

  if ( OneWire::crc8( addr, 7) != addr[7]) {
    lcd.clear();
    lcd.print("Ereur CRC ds18b20");
    delay(1000);
    return;
  }


}

void loop()
{

  // **************************
  // ****   Luminosité     ****
  // **************************
  lumi = analogRead(lumiPin);

  // **************************
  // ****   Allumage LCD   ****
  // **************************
  mouvement = digitalRead(pirPin);

  if (HIGH == mouvement) {
    lcd.backlight();
  }
  else {
    lcd.noBacklight();
  }

  // **************************
  // ****  Reset min & max ****
  // **************************
  if (Date != (int)time[6])
  {
    for (i = 0; i < 6;i++){
      capteur[i][1] = 999999;
      capteur[i][2] = 0;
    }
    time[6] = Date;
  }

  // **************************
  // ****  Affichage date  ****
  // **************************

  DisplayTime();
  lcd.setCursor(0,0);
  if ((Date)<10)
    lcd.print("0");
  lcd.print(Date, HEX);
  lcd.print("/");
  if ((Month)<10)
    lcd.print("0");
  lcd.print(Month, HEX);
  lcd.print("/");
  lcd.print(Year, HEX);
  lcd.print(" ");
  if ((Hour)<10)
    lcd.print("0");
  lcd.print(Hour, HEX);
  lcd.print(":");
  if ((Minute)<10)
    lcd.print("0");
  lcd.print(Minute, HEX);
  lcd.print(":");
  if ((Second)<10)
    lcd.print("0");
  lcd.print(Second, HEX);

  for (i = 0; i < ROW_COUNT((capteur));i++){
    Serial.print("Capteur ");
    Serial.print((int)i);
    Serial.print(" : ");
    for (int y = 0; y < COLUMN_COUNT((capteur));y++){
      Serial.print(capteur[i][y]);
      Serial.print(" / ");
    }
    Serial.println();
  }

  if ((int)Second != (int)time[11])
  {
    capteur[5][0] = map(lumi, 0, 1024, 20, 0);
    capteur[1][0] = bmp085Gettemp_in(bmp085ReadUT());
    capteur[4][0] = bmp085GetPressure(bmp085ReadUP()) * 0.01;
    int chk = DHT11.read(DHT11PIN);
    capteur[0][0] = (int)DHT11.temperature;
    capteur[3][0] = (int)DHT11.humidity;
    getTemp();
    //  if (SignBit) Whole = - Whole ;
    capteur[2][0] = Whole * bar;

    // Update Min MAx
    for (int i = 0; i < 6;i++){
      // Cas capteur offline de temperature
        if (i == 2 && ( capteur[i][0] > 60 || capteur[i][0] < 1)) {}else{
          // cas normaux
          if (capteur[i][0] < capteur[i][1]) capteur[i][1] =  capteur[i][0];
          if (capteur[i][0] > capteur[i][2]) capteur[i][2] =  capteur[i][0];
        }
    }

    lcd.setCursor(19,0);
    lcd.write(5);
    delay(300);

    // Ligne 2 pression
    lcd.setCursor(0,1); 
    lcd.write(4);
    lcd.print(" ");
    sprintf(tampon,"%i",capteur[4][0]);
    lcd.print(tampon);
    lcd.print("hPa ");
    lcd.setCursor(9,1);
    lcd.print("[");
    lcd.print(capteur[4][1]);
    lcd.print("-");
    lcd.print(capteur[4][2]);
    lcd.print("] ");

    // Ligne 3 Temperature IN
    lcd.setCursor(0,2); 
    lcd.write(6);
    lcd.print(" ");
    lcd.print(capteur[0][0]);
    lcd.print("c");
    lcd.setCursor(7,2);
    lcd.print("[");
    lcd.print(capteur[0][1]);
    lcd.print("-");
    lcd.print(capteur[0][2]);
    lcd.print("] ");
    lcd.write(2);
    lcd.print(capteur[3][2]);
    lcd.print("%");

    // Ligne 4 Temperature OUT
    if ( !ds.search(addr)) {
      lcd.setCursor(2,3);
      lcd.print("Capteur offline ");
    }
    else{
      lcd.setCursor(0,3);
      lcd.write(3);
      lcd.print(" ");
      lcd.print(capteur[2][0]);
      lcd.print("c   ");
      lcd.setCursor(7,3);
      lcd.print("[");
      lcd.print(capteur[2][1]);
      lcd.print("-");
      lcd.print(capteur[2][2]);
      lcd.print("]    ");
    }

    delay(100);
    ds.reset_search();

    if (Minute != (int)time[10])
    {
      toUrl="";
      toUrl+="action=new";
      for (i = 0; i < ROW_COUNT((capteur));i++){
        toUrl+="&capteur";
        toUrl+=(int)i;
        toUrl+="=";
        for ( int y = 0; y < COLUMN_COUNT((capteur));y++){
          toUrl+=capteur[i][y];
          toUrl+=",";
        }
        toUrl+=(int)i;
      }

      toUrl+="&submit=Submit";
      Serial.println(toUrl);

      Ethernet.begin(mac, ip , gateway , subnet);

      if (client.connect()) {
        Serial.println("connected");

        client.print( "GET /meteo/query.php?");
        client.print(toUrl);
        client.println( " HTTP/1.1");
        client.println( "Host: 192.168.1.10" );
        client.println( "Content-Type: application/x-www-form-urlencoded" );
        client.println( "Connection: close" );
        client.print("Content-Length: ");
        client.println(toUrl.length());
        client.println();
        client.stop();
      }
      else{
        Serial.println("Impossible d'accèder au WEB");
      }

      if (!client.connected()) {
        Serial.println();
        Serial.println("disconnecting.");
        client.stop();
      }
    }// fin si minute diff

  }
  delay(400);
  time[10] = Minute;
  time[11] = Second;
}


//Celsius to Fahrenheit conversion
int Fahrenheit(int celsius)
{
  return 1.8 * celsius + 32;
}

//Celsius to Kelvin conversion
int Kelvin(int celsius)
{
  return celsius + 273.15;
}

// dewPoint function NOAA
// reference: http://wahiduddin.net/calc/density_algorithms.htm
double dewPoint(double celsius, double humidity)
{
  double A0= 373.15/(273.15 + celsius);
  double SUM = -7.90298 * (A0-1);
  SUM += 5.02808 * log10(A0);
  SUM += -1.3816e-7 * (pow(10, (11.344*(1-1/A0)))-1) ;
  SUM += 8.1328e-3 * (pow(10,(-3.49149*(A0-1)))-1) ;
  SUM += log10(1013.246);
  double VP = pow(10, SUM-3) * humidity;
  double T = log(VP/0.61078);   // temp var
  return (241.88 * T) / (17.558-T);
}

// delta max = 0.6544 wrt dewPoint()
// 5x faster than dewPoint()
// reference: http://en.wikipedia.org/wiki/Dew_point
double dewPointFast(double celsius, double humidity)
{
  double a = 17.271;
  double b = 237.7;
  double temp = (a * celsius) / (b + celsius) + log(humidity/100);
  double Td = (b * temp) / (a - temp);
  return Td;
}
/*******************************************************************************
 * Read a input number from the Serial Monitor ASCII string
 * Return: A binary number or hex number
 *******************************************************************************/
unsigned int SerialNumRead (byte Type)
{
  unsigned int Number = 0;       // Serial receive number
  unsigned int digit = 1;        // Digit
  byte  i = 0, j, k=0, n;        // Counter
  byte  ReceiveBuf [5];          // for incoming serial data

  while (Serial.available() <= 0);

  while (Serial.available() > 0)  // Get serial input
  {
    // read the incoming byte:
    ReceiveBuf[i] = Serial.read();
    i++;
    delay(10);
  }

  for (j=i; j>0; j--)
  {
    digit = 1;

    for (n=0; n<k; n++)          // This act as pow() with base = 10
    {
      if (Type == Binary)
        digit = 10 * digit;
      else if (Type == Hex)
        digit = 16 * digit;
    }

    ReceiveBuf[j-1] = ReceiveBuf[j-1] - 0x30;    // Change ASCII to BIN
    Number = Number + (ReceiveBuf[j-1] * digit); // Calcluate the number
    k++;
  }
  return (Number);   
}

/*******************************************************************************
 * Set time function
 *******************************************************************************/
void SetTime()
{
  Serial.print("Enter hours (00-23): ");
  Hour = (byte) SerialNumRead (Hex);
  Serial.println(Hour, HEX);        // Echo the value
  Hour = Hour & 0x3F;               // Disable century
  Serial.print("Enter minutes (00-59): ");
  Minute = (byte) SerialNumRead (Hex);
  Serial.println(Minute, HEX);      // Echo the value
  Serial.print("Enter seconds (00-59): ");
  Second = (byte) SerialNumRead (Hex);
  Serial.println(Second, HEX);      // Echo the value
  Second = Second & 0x7F;           // Enable oscillator
  Serial.print("Enter day (01-07): ");
  Day = (byte) SerialNumRead (Hex);
  Serial.println(Day, HEX);         // Echo the value
  Serial.print("Enter date (01-31): ");
  Date = (byte) SerialNumRead (Hex);
  Serial.println(Date, HEX);        // Echo the value
  Serial.print("Enter month (01-12): ");
  Month = (byte) SerialNumRead (Hex);
  Serial.println(Month, HEX);       // Echo the value
  Serial.print("Enter year (00-99): ");
  Year = (byte) SerialNumRead (Hex);
  Serial.println(Year, HEX);        // Echo the value

  Wire.beginTransmission(I2C_address);
  Wire.send(0);
  Wire.send(Second);
  Wire.send(Minute);
  Wire.send(Hour);
  Wire.send(Day);
  Wire.send(Date);
  Wire.send(Month);
  Wire.send(Year);
  Wire.endTransmission();
  //I2COUT SDA, I2C_WR, [0,Second,Minute,Hour,Day,Date,Month,Year]
  Serial.println();
  Serial.println ("The current time has been successfully set!");
}

/*******************************************************************************
 * Display time function
 *******************************************************************************/
void DisplayTime()
{
  char tempchar [7];
  byte i = 0;
  Wire.beginTransmission(I2C_address);
  Wire.send(0);
  Wire.endTransmission();

  Wire.requestFrom(I2C_address, 7);

  while(Wire.available())          // Checkf for data from slave
  {
    tempchar [i] = Wire.receive(); // receive a byte as character
    i++;
  }
  Second = tempchar [0];
  Minute = tempchar [1];
  Hour   = tempchar [2];
  Day    = tempchar [3];
  Date   = tempchar [4];
  Month  = tempchar [5];
  Year   = tempchar [6];

  // Display time
  Serial.print("The current time is ");
  Serial.print(Date, HEX);
  Serial.print("/");
  Serial.print(Month, HEX);
  Serial.print("/20");
  if (Year<10)
    Serial.print("0");
  Serial.print(Year, HEX);
  Serial.print("    ");
  Serial.print(Hour, HEX);
  Serial.print(":");
  Serial.print(Minute, HEX);
  Serial.print(".");
  Serial.println(Second, HEX);


}

// Stores all of the bmp085's calibration values into global variables
// Calibration values are required to calculate temp and pressure
// This function should be called at the beginning of the program
void bmp085Calibration()
{
  ac1 = bmp085ReadInt(0xAA);
  ac2 = bmp085ReadInt(0xAC);
  ac3 = bmp085ReadInt(0xAE);
  ac4 = bmp085ReadInt(0xB0);
  ac5 = bmp085ReadInt(0xB2);
  ac6 = bmp085ReadInt(0xB4);
  b1 = bmp085ReadInt(0xB6);
  b2 = bmp085ReadInt(0xB8);
  mb = bmp085ReadInt(0xBA);
  mc = bmp085ReadInt(0xBC);
  md = bmp085ReadInt(0xBE);
}

// Calculate temp_in given ut.
// Value returned will be in units of 0.1 deg C
short bmp085Gettemp_in(unsigned int ut)
{
  long x1, x2;

  x1 = (((long)ut - (long)ac6)*(long)ac5) >> 15;
  x2 = ((long)mc << 11)/(x1 + md);
  b5 = x1 + x2;

  return ((b5 + 8)>>4); 
}

// Calculate pressure given up
// calibration values must be known
// b5 is also required so bmp085Gettemp_in(...) must be called first.
// Value returned will be pressure in units of Pa.
long bmp085GetPressure(unsigned long up)
{
  long x1, x2, x3, b3, b6, p;
  unsigned long b4, b7;

  b6 = b5 - 4000;
  // Calculate B3
  x1 = (b2 * (b6 * b6)>>12)>>11;
  x2 = (ac2 * b6)>>11;
  x3 = x1 + x2;
  b3 = (((((long)ac1)*4 + x3)<<OSS) + 2)>>2;

  // Calculate B4
  x1 = (ac3 * b6)>>13;
  x2 = (b1 * ((b6 * b6)>>12))>>16;
  x3 = ((x1 + x2) + 2)>>2;
  b4 = (ac4 * (unsigned long)(x3 + 32768))>>15;

  b7 = ((unsigned long)(up - b3) * (50000>>OSS));
  if (b7 < 0x80000000)
    p = (b7<<1)/b4;
  else
    p = (b7/b4)<<1;

  x1 = (p>>8) * (p>>8);
  x1 = (x1 * 3038)>>16;
  x2 = (-7357 * p)>>16;
  p += (x1 + x2 + 3791)>>4;

  return p;
}

// Read 1 byte from the BMP085 at 'address'
char bmp085Read(unsigned char address)
{
  unsigned char data;

  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.send(address);
  Wire.endTransmission();

  Wire.requestFrom(BMP085_ADDRESS, 1);
  while(!Wire.available())
    ;

  return Wire.receive();
}

// Read 2 bytes from the BMP085
// First byte will be from 'address'
// Second byte will be from 'address'+1
int bmp085ReadInt(unsigned char address)
{
  unsigned char msb, lsb;

  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.send(address);
  Wire.endTransmission();

  Wire.requestFrom(BMP085_ADDRESS, 2);
  while(Wire.available()<2)
    ;
  msb = Wire.receive();
  lsb = Wire.receive();

  return (int) msb<<8 | lsb;
}

// Read the uncompensated temp_in value
unsigned int bmp085ReadUT()
{
  unsigned int ut;

  // Write 0x2E into Register 0xF4
  // This requests a temp_in reading
  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.send(0xF4);
  Wire.send(0x2E);
  Wire.endTransmission();

  // Wait at least 4.5ms
  delay(5);

  // Read two bytes from registers 0xF6 and 0xF7
  ut = bmp085ReadInt(0xF6);
  return ut;
}

// Read the uncompensated pressure value
unsigned long bmp085ReadUP()
{
  unsigned char msb, lsb, xlsb;
  unsigned long up = 0;

  // Write 0x34+(OSS<<6) into register 0xF4
  // Request a pressure reading w/ oversampling setting
  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.send(0xF4);
  Wire.send(0x34 + (OSS<<6));
  Wire.endTransmission();

  // Wait for conversion, delay time dependent on OSS
  delay(2 + (3<<OSS));

  // Read register 0xF6 (MSB), 0xF7 (LSB), and 0xF8 (XLSB)
  Wire.beginTransmission(BMP085_ADDRESS);
  Wire.send(0xF6);
  Wire.endTransmission();
  Wire.requestFrom(BMP085_ADDRESS, 3);


  while(Wire.available() < 3)
    ;
  msb = Wire.receive();
  lsb = Wire.receive();
  xlsb = Wire.receive();

  up = (((unsigned long) msb << 16) | ((unsigned long) lsb << 8) | (unsigned long) xlsb) >> (8-OSS);

  return up;
}

// FONCTION CAPTEUR temp_in EXTERIEUR
void getTemp() {


  ds.reset();
  ds.select(addr);
  ds.write(0x44,1);

  present = ds.reset();
  ds.select(addr);   
  ds.write(0xBE);

  for ( i = 0; i < 9; i++) {
    data[i] = ds.read();
  }

  LowByte = data[0];
  HighByte = data[1];
  TReading = (HighByte << 8) + LowByte;
  SignBit = TReading & 0x8000;  // test most sig bit

  if (SignBit) {
    TReading = -TReading;
  }
  Tc_100 = (6 * TReading) + TReading / 4;    // multiply by (100 * 0.0625) or 6.25
  Whole = Tc_100 / 100;          // separate off the whole and fractional portions
  Fract = Tc_100 % 100;
  if (Fract > 49) {
    if (SignBit) {
      --Whole;
    }
    else {
      ++Whole;
    }
  }

  if (SignBit) {
    bar = -1;
  }
  else {
    bar = 1;
  }

}
