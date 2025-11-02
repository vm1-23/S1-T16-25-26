# Smart Irrigation System

<!-- First Section -->
## Team Details
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

## Abstract
<details>
  <summary>Detail</summary>

  ### Background
  Water conservation and automation in agriculture are critical in modern environmental and farming contexts.  
  Conventional irrigation systems rely on manual monitoring, leading to over-watering, wastage, and unequal distribution among users.  
  With increasing urbanization and limited water resources, efficient and automated irrigation control has become a vital problem.  

  Digital systems using simple logic components can effectively manage irrigation schedules, monitor usage quotas, and respond to real-time environmental inputs like soil moisture and rainfall.  
  Implementing these functions through hardware logic instead of software demonstrates the power of digital design in sustainable resource management.

  ---

  ### Motivation
  The motivation behind this project is to create an affordable and educational hardware model that showcases intelligent water distribution across multiple users — without using microcontrollers.  

  Multi-user irrigation ensures fair water sharing, while features such as rain detection and soil moisture monitoring prevent unnecessary pumping.  
  Integrating water quota management introduces a controlled resource-allocation mechanism, encouraging responsible water use.  

  The project thus combines environmental awareness with practical learning in combinational and sequential logic design, making it ideal for demonstration on a standard IC trainer kit.

  ---

  ### Unique Contribution
  This project implements a complete hardware-based irrigation management system using logic gates, counters, comparators, multiplexers, and display drivers.  

  Each user has a preset water quota tracked by a down-counter, with the remaining volume displayed on a 7-segment display.  
  The system automatically turns the pump ON when the soil is dry and OFF when rain is detected or quota is depleted.  

  Multi-user switching allows independent monitoring and fair distribution, while manual reset and control switches enable user interaction.  

  The design illustrates key digital concepts — including combinational control logic, state sequencing, resource sharing, and real-time hardware interfacing — making it both environmentally relevant and educational.

</details>


---

## Functional Block Diagram
<details>
  <summary>Detail</summary>
  
  <img width="1280" height="368" alt="image" src="https://github.com/user-attachments/assets/3d4adb8d-66b2-453d-b660-0ad2baa6c0d7" />


  > The diagram represents the interconnection of all modules — including **zone sequencer**, **registers**, **moisture and rain sensors**, and the **controller**.  
  >
  > Each field (zone) has its own quota and moisture input.  
  > Once a zone reaches its quota, control automatically shifts to the next zone based on priority.  
  > Rain detection immediately halts watering across all zones.
</details>


---

## Working
<details>
  <summary>Detail</summary>

  ### Working Principle

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

  ### Functional Table

  | Condition | Rain | Moisture (Dry) | Quota Exceeded | Valve | Action |
  |------------|------|----------------|----------------|--------|---------|
  | Dry & No Rain & Quota Left | 0 | 1 | 0 | 1 | Watering Active |
  | Rain Detected | 1 | X | X | 0 | Stop Irrigation |
  | Moisture Wet | 0 | 0 | X | 0 | Stop Irrigation |
  | Quota Exhausted | 0 | 1 | 1 | 0 | Switch to Next Zone |
  | Manual Override | X | X | 0 | 1 | Force Watering |

  ### Flowchart
  > 1. Start →  
  > 2. Check Rain → If raining → Stop pump → Go back.  
  > 3. Else Check Moisture → If wet → Skip zone.  
  > 4. Else Water Zone →  
  > 5. Check Quota → If exhausted → Move to next zone →  
  > 6. Repeat until all zones complete → End.
</details>

---

## Logisim Circuit Diagram
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

## References
<details>
  <summary>Detail</summary>

  | No. | Reference | Source / Link |
  |:---:|:-----------|:--------------|
  | 1 | Charles H. Roth, *Fundamentals of Logic Design*, Cengage Learning. | — |
  | 2 | M. Morris Mano, *Digital Design*, Pearson Education. | — |
  | 3 | *Automatic Irrigation System Using Digital Logic*, Circuit Digest. | [https://circuitdigest.com/electronic-circuits/automatic-irrigation-system-using-digital-logic](https://circuitdigest.com/electronic-circuits/automatic-irrigation-system-using-digital-logic) |
  | 4 | *Smart Automatic Irrigation Control System*, ResearchGate. | [https://www.researchgate.net/publication/Smart_Automatic_Irrigation_Control_System](https://www.researchgate.net/publication/Smart_Automatic_Irrigation_Control_System) |
  | 5 | *Logisim Evolution - Digital Logic Simulator*, Logisim Evolution Project. | [https://github.com/logisim-evolution/logisim-evolution](https://github.com/logisim-evolution/logisim-evolution) |

</details>




