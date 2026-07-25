/*
  Pico SD Card USB Mass Storage
  ------------------------------
  Exposes a microSD card (SPI mode) as a USB disk drive when the Pico
  is plugged into a PC.

  Board:      Raspberry Pi Pico (earlephilhower/arduino-pico core)
  Tools menu: USB Stack -> Adafruit TinyUSB

  Libraries required (Library Manager):
    - Adafruit TinyUSB Library
    - SdFat - Adafruit Fork

  Wiring (adjust pin #defines below to match your setup):
    SD SCK  -> GP18
    SD MOSI -> GP19
    SD MISO -> GP16
    SD CS   -> GP17
    SD VCC  -> 3V3
    SD GND  -> GND
*/

#include <Adafruit_TinyUSB.h>
#include <SPI.h>
#include <SdFat.h>


// ---- SD card SPI pin configuration ----
#define SD_CS_PIN    17
#define SD_SCK_PIN   18
#define SD_MOSI_PIN  19
#define SD_MISO_PIN  16
#define SD_SPI_MHZ   6   // lower this (e.g. 12) if you get read/write errors

SdFat sd;
SdCard* card;
uint32_t sd_block_count;
const uint16_t SD_BLOCK_SIZE = 512;

Adafruit_USBD_MSC usb_msc;

// ---- USB MSC callbacks ----

// Host wants to read one or more 512-byte blocks starting at lba
int32_t msc_read_cb(uint32_t lba, void* buffer, uint32_t bufsize) {
  uint32_t count = bufsize / SD_BLOCK_SIZE;
  bool ok = card->readSectors(lba, (uint8_t*)buffer, count);
  return ok ? (int32_t)bufsize : -1;
}

// Host wants to write one or more 512-byte blocks starting at lba

int32_t msc_write_cb(uint32_t lba, uint8_t* buffer, uint32_t bufsize) {
  uint32_t count = bufsize / SD_BLOCK_SIZE;
  bool ok = card->writeSectors(lba, buffer, count);
  return ok ? (int32_t)bufsize : -1;
}

// Host has finished a write and wants data flushed to the card
void msc_flush_cb(void) {
  card->syncDevice();
}

// Blink the onboard LED `count` times, pause, repeat. 
void blink_pattern(int count) {
  for (int i = 0; i < count; i++) {
    digitalWrite(LED_BUILTIN, HIGH);
    delay(150);
    digitalWrite(LED_BUILTIN, LOW);
    delay(150);
  }
  delay(1000);
}

bool sd_ok = false;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);

  // Remap SPI pins before SdFat brings up SPI
  SPI.setSCK(SD_SCK_PIN);
  SPI.setTX(SD_MOSI_PIN);
  SPI.setRX(SD_MISO_PIN);

  sd_ok = sd.begin(SD_CS_PIN, SD_SCK_MHZ(SD_SPI_MHZ));

  if (sd_ok) {
    card = sd.card();
    sd_block_count = card->sectorCount();
  } else {
    blink_pattern(5);
  }
  
  // Register the MSC USB interface
  // Set disk vendor id, product id and revision with string up to 8, 16, 4 characters respectively
  usb_msc.setID("TinyUSB ", "Mass Storage    ", "1.0 ");
  //usb_msc.setID("Pico", "SD Card", "1.0");
  usb_msc.setReadWriteCallback(msc_read_cb, msc_write_cb, msc_flush_cb);
  usb_msc.setCapacity(sd_block_count, SD_BLOCK_SIZE);
  usb_msc.setUnitReady(true);
  usb_msc.begin();

}

void loop() {
  TinyUSBDevice.task();
}
