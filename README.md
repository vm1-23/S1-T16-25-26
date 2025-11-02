# 🌱 Smart Irrigation System

<!-- First Section -->
## 👥 Team Details
<details>
  <summary>Detail</summary>

  > **Semester:** 3rd Sem B. Tech. CSE  
  > **Section:** S1  
  > **Team ID:** 16  

  **Members:**  
  > Member-1: Vishal Murugan — 241CS165 — vishalmurugan.241cs165@nitk.edu.in  
  > Member-2: Ritvik Gampa — 241CS147 — ritvikgampa.241cs147@nitk.edu.in  
  > Member-3: Parmeet Singh — 241CS139 — parmeetsingh.241cs139@nitk.edu.in
</details>

---

## 🧾 Abstract
<details>
  <summary>Detail</summary>

  > The **Smart Irrigation System** automates the process of watering multiple agricultural zones using **digital logic design**.  
  > It intelligently decides when and which zone to water based on **soil moisture**, **rain detection**, and **quota usage**.  
  >  
  > The system is designed using **AND**, **OR**, and **NOT** logic gates, integrated through **Verilog HDL** at multiple abstraction levels: **Behavioral**, **Dataflow**, and **Structural**.  
  >  
  > Additionally, the system ensures **efficient water management** by distributing water sequentially to different zones instead of irrigating all at once — optimizing both **pressure stability** and **electricity usage**.  
  >  
  > A **zone sequencer** determines priority, a **register module** stores quota data, and **rain/sun sensors** adjust watering conditions dynamically.
</details>

---

## ⚙️ Functional Block Diagram
<details>
  <summary>Detail</summary>
  
  ![Functional Block Diagram](https://github.com/user-attachments/assets/588c9f81-997e-431b-8da3-0b40f3713d4e)

  > The diagram represents the interconnection of all modules — including **zone sequencer**, **registers**, **moisture and rain sensors**, and the **controller**.  
  >  
  > Each field (zone) has its own quota and moisture input.  
  > Once a zone reaches its quota, control automatically shifts to the next zone based on priority.  
  > Rain detection immediately halts watering across all zones.
</details>

---

## 🔄 Working
<details>
  <summary>Detail</summary>

  ### 💧 Working Principle

  > The Smart Irrigation System ensures **controlled, priority-based watering** of multiple fields (zones).  
  > Each zone has its own **quota** (maximum water limit) and **sensor inputs** (moisture and rain).  
  >  
  > 1. The **Zone Sequencer** (FSM) checks which zone has priority and activates it for watering.  
  > 2. The **Register Module** stores quota data for each zone.  
  > 3. The **Soil Moisture Sensor** detects if soil is dry (logic `0`) or wet (logic `1`).  
  > 4. If the **rain sensor** is active, watering stops regardless of other conditions.  
  > 5. The **Sun-Time Logic** increases watering rate during high sunlight (10 AM–4 PM).  
  > 6. Once a zone’s quota is met, control moves to the next zone automatically.

  ### 🌤️ Why Water is Split Sequentially
  > Instead of watering all zones simultaneously, the system irrigates one zone at a time.  
  > This ensures **better water pressure**, **efficient electricity usage**, and **uniform distribution**.  
  > It also prevents overloading the pump or system circuitry.

  ### ⚡ Functional Table

  | Condition | Rain | Moisture (Dry) | Quota Exceeded | Valve | Action |
  |------------|------|----------------|----------------|--------|---------|
  | Dry & No Rain & Quota Left | 0 | 1 | 0 | 1 | Watering Active |
  | Rain Detected | 1 | X | X | 0 | Stop Irrigation |
  | Moisture Wet | 0 | 0 | X | 0 | Stop Irrigation |
  | Quota Exhausted | 0 | 1 | 1 | 0 | Switch to Next Zone |
  | Manual Override | X | X | 0 | 1 | Force Watering |

  ### 🧠 Flowchart
  > 1. Start →  
  > 2. Check Rain → If raining → Stop pump → Go back.  
  > 3. Else Check Moisture → If wet → Skip zone.  
  > 4. Else Water Zone →  
  > 5. Check Quota → If exhausted → Move to next zone →  
  > 6. Repeat until all zones complete → End.
</details>

---

## 🧩 Logisim Circuit Diagram
<details>
  <summary>Detail</summary>

  > The **Logisim Circuit** represents:
  > - Automatic pump control (AND/OR gates)  
  > - Soil moisture sensor input  
  > - Rain detection logic with NOT gate  
  > - Multi-zone quota system using counters and comparators  
  > - Zone selection via multiplexer  
  > - Quota display via BCD-to-7-segment decoder  
  > - LED indicators for zone activity and quota completion  
  >  
  > A **6-bit to BCD display converter** was added to display usage levels.
</details>

---

## 💻 Verilog Code
<details>
  <summary>Detail</summary>

  ```verilog
  //================================================================
  // SMART IRRIGATION SYSTEM
  // Modeled across Behavioral, Dataflow, and Structural levels
  //================================================================
  module smart_irrigation #(parameter NUM_USERS=4, WIDTH=6, DEBOUNCE_WIDTH=20)(...);
  ...
  endmodule

  // TESTBENCH
  module tb_smart_irrigation;
  ...
  endmodule
🧩 Key Features

Behavioral Modeling: FSM-based zone sequencing

Dataflow Modeling: Quota counting and sunlight multiplier

Structural Modeling: Debounce submodule instantiation

Testbench Simulation: Automates rain, dry, and manual override events

</details>
📚 References
<details> <summary>Detail</summary>

Charles H. Roth, Fundamentals of Logic Design, Cengage Learning.

M. Morris Mano, Digital Design, Pearson Education.

Automatic Irrigation System Using Digital Logic — Circuit Digest

Smart Automatic Irrigation Control System — ResearchGate

Logisim Evolution Project — GitHub

</details> ```
