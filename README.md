
![title](images/title.png)


# 📈 Project 6 DIGISCOPE

## 1. Project Summary (프로젝트 요약)
Basys3(Artix-7 FPGA) 기반 Custom IP를 활용한 PWM 생성·측정 및 TFT LCD·CLCD 연동 디지털 오실로스코프(DIGISCOPE) 구현

## 2. Key Features (주요 기능)

### 📡 Signal Generation (PWM 신호 생성) 
- UART 명령(`p(Period [µs])`, `d(Duty [%])`)으로 주기 및 듀티 사이클 실시간 조정
- SW[0] 스위치로 PWM 파형 출력 ON/OFF 제어

### 📊 Signal Measurement (PWM 신호 측정) 
- 입력 PWM 신호의 주기(period), HIGH 시간(high count)을 클럭 카운트로 측정
- 주파수(Hz) 및 듀티(%) 계산은 MicroBlaze RISC-V(C 코드)에서 수행

### 🖥️ Waveform Display (파형 표시)
- 320×240 TFT LCD에 PWM 파형을 실시간 렌더링
- 전압 스케일: 1V / 3.3V / 5V per div
- 시간 스케일: 100µs / 500µs / 1ms / 5ms per div
- RUN / STOP 모드 전환
- Dark / White 테마 전환

### ⌨️ Button Control (버튼 제어)
| 버튼 | 기능 |
| :---: | :---: |
| BTN0 | 전압 스케일 변경 (V/div) |
| BTN1 | 시간 스케일 변경 (T/div) |
| BTN2 | RUN / STOP 전환 |
| BTN3 | Dark / White 테마 전환 |

### 💬 Status Display (상태 표시)
CLCD에 현재 측정값 및 설정값을 텍스트로 표시
```
[R] H:500u V:1V     ← RUN/STOP 모드, 시간 스케일, 전압 스케일
[D] F:1.0k D:50%    ← Dark/White 테마, 측정 주파수, 측정 듀티
```


## 🛠 3. Tech Stack (기술 스택)

### 3.1 Language (사용언어)

![Verilog](https://img.shields.io/badge/Verilog-FF6600?style=for-the-badge&logo=v&logoColor=white)![C](https://img.shields.io/badge/C-00599C?style=for-the-badge&logo=c&logoColor=white)

### 3.2 Development Environment (개발 환경)
| ![vivado](images/vivado.png) | ![vitis](images/vitis.jpg) | ![vscode](images/vscode.png) |
| :---: | :---: | :---: |
| **AMD Vivado** | **AMD Vitis** | **VS Code** |

### 3.3 Collaboration Tools (협업 도구)

![Github](https://img.shields.io/badge/GitHub-100000?style=for-the-badge&logo=github&logoColor=white)![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)![Notion](https://img.shields.io/badge/Notion-000000?style=for-the-badge&logo=notion&logoColor=white)


## 📂 4. Project Structure (프로젝트 구조)

### 4.1 Project Tree (프로젝트 트리)

```
Project_6_Oscilloscope/
├── Vivado/                                     # Vivado 프로젝트 (HW 설계)
│   ├── DIGISCOPE.xpr                           # Vivado 프로젝트 파일
│   ├── DIGISCOPE.srcs/
│   │   ├── sources_1/bd/
│   │   │   ├── Digiscope/                      # CLCD 검증용 Block Design
│   │   │   └── DIGISCOPE_TEST1/                # 최종 오실로스코프 Block Design
│   │   │       # (MicroBlaze RISC-V, AXI SmartConnect,
│   │   │       #  myip_pwm, myip_tft_lcd_cntr, CLCD,
│   │   │       #  AXI UARTLite, AXI GPIO, CLK Wizard)
│   │   └── constrs_1/imports/fpga/
│   │       └── Basys-3-Master.xdc              # Basys3 핀 제약 파일
├── Vitis/                                      # Vitis 프로젝트 (SW 개발)
│   ├── platform_DIGISCOPE_TEST1/               # MicroBlaze RISC-V 플랫폼
│   ├── app_DIGISCOPE_TEST1/src/
│   │   ├── helloworld.c                        # 메인 엔트리 포인트
│   │   ├── app_digiscope.c / .h                # 오실로스코프 핵심 애플리케이션 로직
│   │   ├── tft_lcd.c / .h                      # TFT LCD 드라이버 및 파형 렌더링
│   │   ├── pwm.c / .h                          # PWM 생성·측정 AXI 드라이버
│   │   ├── CLCD.c / .h                         # Character LCD 드라이버
│   │   └── def.h                               # 공통 타입 정의
│   ├── CLCD_test/                              # CLCD 기능 검증 테스트 앱
│   └── Custom_source/                          # 재사용 가능 공통 소스
├── ip_repo/                                    # 커스텀 AXI IP 저장소
│   ├── myip_pwm_1_0/
│   │   └── src/PWM_Generator_ver3.v            # PWM 생성기 + 측정 회로 (Verilog)
│   ├── myip_tft_lcd_cntr_1_0/
│   │   └── src/tft_lcd_spi_tx.v                # ILI9341 SPI 1byte 송신기 (Verilog)
│   └── CLCD_1_0/
│       └── src/controller.v                    # Character LCD 제어기 (Verilog)
├── images/                                     # README 이미지 리소스
├── DIGISCOPE_TEST1_wrapper.xsa                 # 최종 빌드용 HW 내보내기 파일
└── README.md
```

### 4.2 RTL Block Design (RTL 블록 디자인)

![RTL BD](images/DIGISCOPE_RTL_BD.png)


### 4.3 Hardware Block Diagram (하드웨어 블록다이어그램)

![BlockDesign](images/DIGISCOPE_BlockDesign.png)



### 4.4 Flow Chart (순서도)

![Flowchart](images/DIGISCOPE_Flowchart.png)


## 🔌 5. Custom IP Description (커스텀 IP 설명)

### 5.1 PWM Generate & Measure IP (PWM 생성 및 측정 IP)

| 역할 | 설명 |
| :--- | :--- |
| PWM 생성 | AXI register에서 `period_count`, `duty_count`를 받아 100MHz 클럭 기준 PWM 출력 생성 |
| 신호 측정 | 입력 PWM(루프백)의 rising/falling edge를 이용해 `measured_period_count`, `measured_high_count` 측정 |
| Duty 계산 | Verilog에서 나눗셈을 하지 않고, Vitis C 코드에서 연산 처리 |

**AXI Register Map**

| Offset | 이름 | 방향 | 설명 |
| :---: | :--- | :---: | :--- |
| 0x00 | period_count | W/R | PWM 주기 카운트 (주기[µs] × 100) |
| 0x04 | duty_count | W/R | PWM HIGH 카운트 (period_count × duty%) |
| 0x08 | current_period_cnt | R | 현재 설정된 주기 카운트 read-back |
| 0x0C | current_duty_cnt | R | 현재 설정된 duty 카운트 read-back |
| 0x10 | measured_period_cnt | R | 측정된 PWM 주기 카운트 |
| 0x14 | measured_high_cnt | R | 측정된 PWM HIGH 카운트 |

### 5.2 TFT LCD SPI Control IP (TFT LCD SPI 제어 IP)

| 역할 | 설명 |
| :--- | :--- |
| SPI 송신 | ILI9341 (320×240) 대상으로 SPI Mode 0, MSB first, ~1MHz SCK 통신 |
| 명령/데이터 | 9-bit 데이터 (bit[8]=DC, bit[7:0]=데이터)로 명령과 픽셀 구분 |
| AXI 연동 | FILL(전체 배경 채우기) / PIXEL(단일 픽셀 쓰기) 명령을 AXI register로 수신 |

**AXI Register Map**

| Offset | 이름 | 방향 | 설명 |
| :---: | :--- | :---: | :--- |
| 0x00 | CTRL | W/R | bit0=start 트리거(W) / bit1=busy, bit2=done, bit3=init_done(R) |
| 0x04 | CMD | W | 명령 코드 (1=FILL: 전체 채우기, 2=PIXEL: 단일 픽셀 쓰기) |
| 0x08 | X | W | X 좌표 [8:0] (0~319) |
| 0x0C | Y | W | Y 좌표 [8:0] (0~239) |
| 0x10 | COLOR | W | RGB565 색상 [15:0] |

> **동작 순서:** CMD / X / Y / COLOR 레지스터 설정 → CTRL[0]=1 write → busy=0 & done=1 확인

### 5.3 CLCD Control IP (CLCD 제어 IP)

| 역할 | 설명 |
| :--- | :--- |
| 인터페이스 | 16×2 Character LCD(HD44780), I2C(PCF8574) 경유 4-bit 병렬 인터페이스 |
| AXI 연동 | AXI-Lite Slave를 통해 I2C 데이터 및 send 트리거 수신 |

**AXI Register Map**

| Offset | 이름 | 방향 | 설명 |
| :---: | :--- | :---: | :--- |
| 0x00 | CTRL | W | bit[6:0]=I2C 슬레이브 주소 (7-bit), bit7=send 트리거 (상승 에지) |
| 0x04 | DATA | W | bit[7:0]=전송 데이터 바이트, bit8=RS (0=커맨드, 1=문자 데이터) |

> **동작 순서:** DATA 레지스터 설정 → CTRL에 `(슬레이브 주소 | 0x80)` write → `슬레이브 주소` write (send 하강 에지)


## 💻 6. UART Command Interface (UART 명령어)


| 명령어 | 예시 | 설명 |
| :--- | :--- | :--- |
| `p<값>` | `p1000` | PWM 주기를 1000µs(1kHz)로 설정 |
| `d<값>` | `d50` | PWM 듀티를 50%로 설정 |
| `s` | `s` | 현재 측정값 출력 (주기, HIGH 시간, 듀티, 주파수) |
| `help` | `help` | 명령어 목록 출력 |

> PWM 파라미터를 UART 통신을 통해 PC 터미널에서 변경 가능


## 🏁 7. Final Product & Demonstration (완성품 및 시연)

### 7.1 Final Product (완성품)

| **RUN 모드** | **White 테마** |
| :---: | :---: |
| <img src="images/Run.jpg" width="350"> | <img src="images/White_theme.jpg" width="350"> |

| **시간 스케일 500µs/div** | **시간 스케일 5ms/div** |
| :---: | :---: |
| <img src="images/Horizontal_500u.jpg" width="350"> | <img src="images/Horizontal_5ms.jpg" width="350"> |

| **전압 스케일 3.3V/div** | **전압 스케일 5V/div** |
| :---: | :---: |
| <img src="images/vertical_3.3.jpg" width="350"> | <img src="images/vertical_5v.jpg" width="350"> |

<br>

### 7.2  Demonstration (시연 영상)

<a href="https://youtube.com/playlist?list=PL6xfXHA4BYR-J2YdupXh5K9cHNIxC0NS_&si=U47yTLVHOldbWqq0" target="_blank">
  <img src="images/youtube.jpg" alt="Watch Demo Video" width="300" />
</a>

*이미지를 클릭하면 시연 영상(유튜브)로 이동합니다.*





## 8. Troubleshooting (문제 해결 기록)

### 8.1 Official Datasheet vs Custom IP Mismatch (공식 데이터시트와 Custom IP 불일치)

🔍 **Issue (문제 상황)**

- HD44780 표준 초기화와 Custom IP 구조 불일치

❓ **Analysis (원인 분석)**

- HD44780 표준 초기화 방식과 FPGA 기반 Custom IP 내부 동작 구조 불일치 발생
- FSM 내부 200ms 대기 및 High/Low Nibble 분리 전송 방식 확인

❗ **Action (해결 방법)**

- 초기화 단계별 추가 Delay 제거 후 초기 전원 안정화(50ms)만 유지
- 기존 8bit 초기화 방식 (0x30→0x20)을 IP 구조에 맞게 4bit 초기화 방식 (0x32)로 변경

✅ **Result (결과)**

- Custom IP 구조와 초기화 시퀀스를 일치시켜 LCD 초기화 성공
- Vitis 단계에서 불필요한 대기 제거

---

### 8.2 SPI Bit Timing Transmission Error (SPI 통신 비트 타이밍 전송 오류)

🔍 **Issue (문제 상황)**

- 전원과 SPI 통신은 정상 확인되나 LCD가 빨간색 화면으로 전환되지 않음

❓ **Analysis (원인 분석)**

- 마지막 bit 전송 전 CS가 해제되어 초기화 명령이 손실되는 문제 확인

❗ **Action (해결 방법)**

- SPI TX FSM 수정 후 SCK rising edge 8회 발생을 보장
- Sleep Out → Display ON → RED Fill 초기화 순서를 재구성

✅ **Result (결과)**

- TFT LCD 초기화 완료 및 전체 RED 화면 출력 검증

---

### 8.3 TFT LCD Flickering & Button Response Delay (TFT LCD 깜빡임 및 버튼 응답 지연)

🔍 **Issue (문제 상황)**

- TFT 화면 깜빡이며 버튼의 입력이 무시되는 현상이 발생

❓ **Analysis (원인 분석)**

- TFT가 매 갱신마다 Fill → Grid → Wave를 전체 다시 그리는 구조 사용
- Pixel 단위 Busy 대기로 CPU 점유율이 증가하여 화면 깜빡임과 버튼 지연 발생

❗ **Action (해결 방법)**

- `Redraw` 플래그를 적용하여 필요한 경우에만 TFT 갱신
- RUN 상태에서 약 1.5초 주기 갱신 및 버튼 디바운싱 적용

✅ **Result (결과)**

- 불필요한 TFT 재렌더링 감소 및 버튼 입력 안정성 향상
- 주기 제어 기반 화면 출력 안정화