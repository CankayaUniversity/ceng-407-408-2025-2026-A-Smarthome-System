Çankaya Üniversitesi
A SMART HOME SYSTEM
Group Members:
İbrahim Ersan Özdemir – 202211054
Deniz Arda Çınarer – 202211019
Duhan Ayberk Seven – 202211062
Enis Mirsad Şengül – 202211065
Instructor : Murat Koyuncu
Introduction
The proliferation of the Internet of Things (IoT) has transitioned from a futuristic concept
to a practical, everyday reality, fundamentally altering human interaction with physical
environments. This technological shift has catalyzed the rapid development and adoption of
smart home systems. In the contemporary market, commercial platforms such as Google
Home, Amazon Alexa, and Apple HomeKit have popularized the concept of home
automation, primarily focusing on convenience and voice-activated controls.

However, despite their prevalence, many existing commercial systems and homes
advertised as "smart" often lack the comprehensive functionalities that users expect. These
systems frequently operate as closed ecosystems with limited capabilities, prioritizing user
convenience over holistic security, in-depth environmental monitoring, and intelligent,
proactive automation. A significant gap exists between systems that offer simple, command-
based automation and the growing need for integrated platforms that intelligently manage a
home's safety, security, and environment.

The challenge lies not only in connecting devices but in creating a cohesive system that
can sense, process, and act upon complex and critical information. Many platforms fail to
adequately address the fundamental security and safety concerns of homeowners, such as the
immediate detection of environmental threats like fire, flooding, or unauthorized intrusion.
Furthermore, while a system may alert a user to motion, it often lacks the intelligence to
differentiate a benign event (a resident returning home) from a genuine threat (an intruder).
This limitation places the burden of analysis and response entirely on the end-user.

This project, "A Smarthome System", is designed to address these limitations and bridge
this functional gap. The project proposes the design and development of a comprehensive,
multi- faceted smart home system that integrates environmental monitoring, advanced
security, and intelligent automation using IoT technologies.

The core of the proposed system is architected around three essential, interconnected
modules:

An IoT Sensor Module responsible for real-time data acquisition from the home
environment, utilizing a suite of sensors for heat, humidity, smoke, water, and images.
A Cloud-Based Web Application serving as the central nervous system, responsible
for receiving, processing, and storing the collected data, and presenting it to users.
A Mobile Application designed to provide end-users with uninterrupted, remote
monitoring capabilities and instant notifications.
A distinguishing feature of this project is the deep integration of artificial intelligence (AI)
for security analysis. The system will not merely report motion; it will actively process
captured image data to identify human movement, compare it against a database of known
residents, and intelligently identify unauthorized individuals entering the home. This moves
the system from a passive reporter to an active participant in home security.

This endeavor aligns with broader technological and societal goals, specifically contributing to
the UN Sustainable Development Goal 9: "Industry, Innovation, Technology, and
Infrastructure". By focusing on research and development in the increasingly vital fields of
IoT, AI, and data management, this project aims to enhance technological capabilities and
foster innovation.

Project Objectives
To achieve the vision laid out in the introduction, the project is guided by one primary goal,
which is broken down into several specific, measurable sub-objectives.

1.1. Main Objective
The main objective of this project is to design and develop a robust, integrated smart home
system that monitors the indoor environment, ensures resident safety, and performs intelligent
automation using Internet of Things (IoT) technologies.

This system is intended to provide residents with peace of mind by enabling them to
monitor their homes remotely from anywhere and receive instantaneous notifications
regarding critical events such as fire, flooding, or burglary.

1.2. Sub-Objectives
To successfully realize the main objective, the project will focus on the following four
key sub-objectives:

To Implement Comprehensive Monitoring: This involves the deployment of a
robust environmental sensing network. The system must collect and process real-time
data from a variety of sensors, including but not limited to temperature, humidity,
smoke, and water level detection. It must be capable of immediately and reliably
notifying users in the event of emergencies like fire or flooding.
To Integrate Artificial Intelligence (AI) for Security: This objective focuses on
creating an intelligent security component. Upon the detection of human motion, the
system will automatically capture camera footage and utilize AI processing models to
analyze the visual data. The goal is to accurately distinguish between authorized
residents and unauthorized persons, thereby reducing false alarms and providing
actionable security alerts.
To Ensure Seamless User Accessibility: This objective is to provide continuous and
intuitive remote access to the home's status. This will be achieved through the
development of two primary user interfaces: a comprehensive web application
(Module 2) for detailed data visualization and management, and a mobile application
(Module 3) for on-the-go monitoring and push notifications.
To Enable Action-Based Automation: This objective aims to extend the system’s
functionality beyond passive monitoring into active home control. The system will be
designed to enable action-based automation, allowing it to control actuators (e.g.,
smart curtains, air conditioning) based on predefined thresholds or rules derived from
sensor data (e.g., adjusting curtains based on light intensity or activating AC based on
temperature)
Scope
To ensure a clear focus and successful completion, the project's scope is defined in two
parts: the core functionalities required for project completion and the extended functionalities
identified as potential future work.

1.3. Core Functionality (Minimum Scope)
The successful completion of this project is contingent upon the stable and functional
implementation of its three core modules and the integrated AI feature.

The IoT Sensor Module (Module 1): This foundational module is responsible for all
data acquisition. The minimum scope includes the successful integration and operation
of sensors for temperature, humidity, smoke, water level , and motion (PIR) , as well
as a camera for visual data capture.
The Cloud-Based Web Application (Module 2): This module serves as the central
backend and data hub. It must be capable of receiving all data from the IoT module,
securely storing this data , and presenting both real-time and historical data to the user
via a web interface.
The Mobile Monitoring Application (Module 3): This module provides the primary
interface for end-user remote interaction. It must allow users to monitor their homes
from anywhere , visualize sensor data , and, most critically, receive instant push
notifications for emergency events.
AI-Based Recognition Feature: A non-negotiable component of the core scope is the
development and integration of a stable AI-based recognition feature. The system
must successfully execute the control flow of detecting motion, capturing an image,
and applying an AI model to classify the detected person as "authorized" or
"unauthorized".
1.4. Extended Scope (Potential Future Work)
While the following features are central to the project's long-term vision, they are
considered outside the minimum scope required for the CENG 407 project. They represent
logical extensions and future work that can be built upon the core architecture.

Seamless Integration of New Hardware: Designing the architecture to be fully
scalable, allowing for the easy integration of new, unplanned sensors (e.g., light
sensors, sound sensors) and actuators (e.g., relays, servo motors).
Scenario-Based Automation Engine: Implementing an advanced, IFTTT-style (If
This, Then That) rule engine. This would allow users to create personalized
"scenarios" (e.g., "Away Mode," "Night Mode") and complex automation rules, such
as "IF (motion is detected) AND (AI detects unauthorized person) AND (Time is
Night) THEN (Turn on all lights) AND (Send high-priority alert)".
Energy Consumption Monitoring: Integrating non-invasive current transformer
sensors (e.g., SCT-013) to monitor real-time power (W) and cumulative energy (kWh)
usage. This would provide users with actionable insights into energy inefficiency and
contribute directly to UN Sustainable Development Goals 7 and 9.
Advanced AI Analysis: Expanding the AI module's capabilities beyond security to
include safety and wellness features. This could involve using pose estimation models
(like MediaPipe) for fall detection to ensure elderly safety or implementing a sound
classification model to detect specific abnormal sounds like glass breaking or a smoke
alarm.
Literature Review
The smart home ecosystem has evolved from simple remote-controlled appliances to
integrated environments that use Internet of Things (IoT) architectures, edge gateways, and
artificial intelligence–based automation. Recent work often describes smart homes in layered
architectures such as perception, network, and application layers, where low-power wireless
protocols including Wi-Fi, Bluetooth Low Energy (BLE), and Zigbee/Thread connect sensors,
actuators, and controllers. Across the literature, the main research priorities are
interoperability, security and privacy, and intelligent, context-aware automation under
resource constraints.

Interoperability and Standardisation
The fragmentation of vendor ecosystems has made smart home deployment difficult,
leading to the development of unified standards such as the Matter specification by the
Connectivity Standards Alliance (CSA). Matter provides IP-based connectivity, standardised
device onboarding, and local multivendor control, enabling communication between different
classes of smart devices such as locks, sensors, appliances, and HVAC systems [3]. Industry
reports highlight Matter’s growing device support and improved developer workflows as
important drivers of adoption. However, in real homes, mixed ecosystems with both Matter-
certified and legacy devices are still common, and architectural guidelines for bridging these
environments are still limited in the literature [3,4].

Security and Privacy Considerations
Security is a central concern in smart home design, especially as the number of
devices and communication channels increases. Empirical studies on early platforms revealed
vulnerabilities such as overly permissive automation rules and weak onboarding procedures
that allowed unauthorised device control. More recent surveys extend the threat model to the
entire data lifecycle and analyse both technical exploits and privacy risks for users [1,4].
Proposed countermeasures include hardware roots of trust, mutual authentication, encrypted
communication, and capability isolation. The literature also stresses that usable security
through clear user interfaces is essential for widespread adoption.

Edge-First Architecture and Resilience
Recent studies increasingly promote edge-first architectures to reduce dependence on
continuous cloud connectivity. Moving sensing, analytics, and decision-making from remote
clouds to local gateways reduces latency, improves privacy, and allows systems to continue
operating during internet outages [1,3]. In smart homes, edge hubs can run lightweight
machine learning models for occupant detection, anomaly recognition, and real-time
automation, while cloud services remain responsible for long-term analytics. This design is
particularly important for safety-critical tasks such as intrusion detection or fire alarms.
However, maintaining secure and scalable edge infrastructures under resource constraints
remains a challenge [1,3].

AI-Driven Automation and Activity Recognition
Machine learning enables advanced capabilities in smart homes, including human
activity recognition, predictive scheduling, and reinforcement learning–based optimisation of
HVAC and lighting systems. Deep learning models such as convolutional and recurrent neural
networks are widely used for these tasks [2,3]. Key challenges include dataset collection in
real homes, robustness against noisy sensor data, and efficient inference on edge devices.
Several studies also emphasise the importance of human-in-the-loop mechanisms to reduce
false positives and maintain user trust [2–4].

Energy Optimisation and Sustainability
Smart home systems increasingly focus on sustainability through adaptive scheduling,
demand response, and predictive energy management. Review studies show that user
acceptance strongly depends on visible energy savings, simple override controls, and
integration with utility systems [3,4]. Edge-based controllers that work without constant cloud
access can further reduce bandwidth usage and improve resilience. Nevertheless, these
solutions require reliable context sensing and accurate prediction models.

Human Factors, Usability and Adoption
Human factors play a crucial role in the adoption of smart home technologies. User
studies report gaps in security awareness, privacy understanding, and update practices. With
the growth of multimodal interfaces, recent research recommends transparent onboarding
mechanisms and configurable privacy dashboards to support user trust [2,4]. Although
standards such as Matter reduce vendor lock-in, mixed ecosystems can still introduce usability
challenges [3].

Synthesis and Research Gaps
Although interoperability, security, edge computing, and AI-based automation are all
well studied individually, their joint evaluation in real-world deployments remains limited.
There is still a lack of open benchmarks for on-device AI in realistic smart home
environments. Moreover, long-term user trust in edge-based AI systems is not sufficiently
explored in current studies. This project aims to address these gaps by combining
interoperable frameworks, secure local analytics, and adaptive automation policies in a real-
world smart home deployment [1–4].

Conclusion
In summary, the literature highlights interoperability as a core enabler, security and
privacy as fundamental requirements, and intelligent automation as the main value
proposition for users. Effective smart home systems must integrate these three dimensions in
a unified architecture. Building on this perspective, the present study proposes an edge-
centric, AI-enabled smart home framework designed for real-world evaluation.

Technology Review
This section provides a comprehensive technical analysis of the leading smart home
ecosystems currently dominating the market: Samsung SmartThings, Apple HomeKit, Google
Home, and Home Assistant [ 5 ]. By evaluating their underlying architectures, communication
protocols, security mechanisms, and feature sets, this review aims to identify the specific
strengths and architectural trade-offs of each platform. The insights gained from this
comparative analysis will serve as a foundational benchmark for the architectural decisions,
component selection, and privacy strategies in the development of our project [ 6 ].

1. Samsung SmartThings
1.1. System Overview
Samsung SmartThings is a mature smart home platform featuring one of the broadest
device compatibilities on the market. Although initially built around a hardware "Hub," it
has evolved into a hybrid ecosystem that unifies Samsung's own devices (TVs,
refrigerators, etc.) and hundreds of third-party products under a single application, blending
cloud and local processing [ 7 ].
1.2. Technical Architecture and Topology
SmartThings' architecture utilizes a hybrid (cloud + local) structure:
● SmartThings Cloud: The platform's brain resides in the cloud. Most devices
(especially Wi-Fi-connected ones and third-party cloud integrations) connect to
Samsung's servers to process commands, run automations, and communicate with the
app.
● SmartThings Hub: The SmartThings Hub (or compatible hubs like Aeotec) acts as a
bridge for devices communicating via local protocols (Zigbee, Z-Wave). It receives
data from these devices and transmits it to the cloud [ 7 ].
● Edge Drivers: Samsung's newer architecture supports a system called "Edge Drivers."
This allows compatible devices and automations to run locally directly on the Hub,
even without an internet connection. This reduces latency and increases reliability [ 8 ].
● Topology: Devices (sensors, bulbs) connect to a Hub (via Zigbee/Z-Wave/Thread) or
directly to the home network (via Wi-Fi/Matter). The Hub and Wi-Fi devices
communicate with the SmartThings Cloud. The mobile application (client) also sends
commands to this cloud.
1.3. Communication Protocols and Standards
SmartThings is one of the most flexible platforms in terms of protocol support:

● Wi-Fi: For standard network devices.
● Zigbee & Z-Wave: Supports the two most common local smart home protocols via a
Hub.
● Matter & Thread: New-generation Hubs support the Matter standard and its
underlying Thread network protocol, further expanding the ecosystem [5].
● Bluetooth: Generally used for the initial setup (onboarding) of devices.
1.4. Functionality and Feature Set
The platform is managed via the "SmartThings" mobile app and offers rich functionality:

● Broad Device Support: It has the widest third-party device support on the market,
working seamlessly with non-Samsung brands (e.g., Philips Hue, Yale, Ring).
● Automations (Routines): Allows for the creation of powerful "If-Then" logic
automations.
● Scenes: Groups of commands that set multiple devices to predefined states with a
single touch.
● Samsung Ecosystem: Provides deep integration with Samsung TVs, soundbars,
refrigerators, and washing machines.
● Voice Assistant: Compatible with Bixby (Samsung), Google Assistant, and Amazon
Alexa.
●
1.5. Security and Data Privacy
● Security: The Samsung Knox platform provides security in the Hub hardware and
software. Communication is encrypted [ 10 ].
● Data Privacy: SmartThings collects usage data to improve and personalize the
service. Data is subject to Samsung's general privacy policy and may be shared with
partners. Data processing largely occurs in the cloud (excluding Edge Drivers).
2. Apple HomeKit
2.1. System Overview
Apple HomeKit is a security and privacy-focused smart home framework deeply integrated
into Apple's iOS, macOS, and tvOS operating systems. The ecosystem is centered around the
"Home" app and the Siri voice assistant [ 11 ].

2.2. Technical Architecture and Topology
HomeKit uses a local-first and decentralized hub architecture:
● Home Hub: A "Home Hub" is required for HomeKit to operate. This is a role
assigned via software and is executed by an Apple TV, HomePod, or HomePod mini
within the home.
● Local Processing: All automation logic and device communication are processed
locally on this Home Hub instead of being sent to the cloud. Automations continue to
function even if the internet connection is lost [ 12 ].
● Topology: Devices (Wi-Fi, Bluetooth, Thread/Matter) communicate directly with the
Home Hub over the local network. The "Home" app on an iPhone also communicates
directly with the Home Hub when on the local network.
● Remote Access: When the user is away from home, their iPhone connects to the
Home Hub via a secure tunnel through iCloud. Apple cannot see the commands; it
only transports the encrypted data [ 11 ].
2.3. Communication Protocols and Standards
● Wi-Fi & Bluetooth LE: The initial versions of HomeKit were based on these two
protocols.

● Matter & Thread: Apple has played a leading role in the development of the Matter
standard. The HomePod mini and newer Apple TV models act as "border routers" for
Thread, connecting these devices to the network [ 9 ].

● No Zigbee/Z-Wave Support: HomeKit does not directly support these protocols. A
HomeKit-compatible bridge is required to use such devices.

2.4. Functionality and Feature Set
● Home App: The central application for managing all devices, scenes, and
automations.
● Siri Integration: The platform's greatest strength is its deep integration with Siri.
● Automations: Automations can be set based on location, time, sensor triggers, or the
status of other devices.
● HomeKit Secure Video (HKSV): A feature for compatible cameras. Video analysis
is performed locally on the Home Hub, not in the cloud. The video is then encrypted
and uploaded to iCloud in a way that even Apple cannot access [ 12 ].
● Adaptive Lighting: Automatically adjusts the color temperature of compatible lights
throughout the day.
2.5. Security and Data Privacy
This is HomeKit's strongest area:

● End-to-end Encryption: All communication between the Home Hub, devices, and
the user's Apple devices is end-to-end encrypted. No one, including Apple, can read
the content of this data [ 11 ].
● No Data Collection: Apple does not collect smart home usage data for advertising or
profiling purposes. Privacy is a core design principle of the platform.
● Certification: In the past, MFi (Made for iPhone) certification was mandatory,
ensuring hardware security.
3. Google Home (Google Nest)
3.1. System Overview
Google Home is a smart home ecosystem centered on the Google Assistant, making it
exceptionally strong in artificial intelligence and voice control. Initially shaped around
"Google Home" speakers, the platform now encompasses a wide range of hardware under the
Nest brand and thousands of third-party integrations [ 13 ].

3.2. Technical Architecture and Topology
Google's architecture, unlike Apple's, is cloud-centric:

● Google Cloud: The platform's brain is Google's cloud servers. Nearly all automation
logic, device management, and third-party integrations run in the cloud [ 13 ].
● Device Connection: Nest speakers, displays, and most third-party devices connect
directly to the Google Cloud via the home's Wi-Fi network.
● Topology: When a user says, "Hey Google, turn on the lights," this voice command is
sent to Google's servers for processing. The server understands the command and
sends it to the relevant device's cloud.
● Local Processing (Limited): With the advent of the Matter standard, new devices like
the Nest Hub and Nest Wifi Pro are beginning to act as "Thread border routers,"
allowing some Matter commands to execute faster on the local network. However, the
core architecture remains dependent on the cloud [1 4 ].
3.3. Communication Protocols and Standards
● Wi-Fi & Bluetooth: These are the mainstays of the ecosystem.
● Matter & Thread: Google is a strong proponent of Matter, and its new hardware
comes with Thread support.
● No Zigbee/Z-Wave Support: It does not directly support local protocols like
SmartThings does.
3.4. Functionality and Feature Set
● Google Assistant: The most advanced and conversational voice assistant on the
market.
● Routines: Offers automations based on presence or voice commands. It is also
possible to write more advanced automations using the Script Editor.
● Nest Ecosystem: Offers deep and seamless integration with Nest Cams, Nest
Thermostats, and Nest Doorbells.
● Cast Technology: Highly successful in casting audio and video between devices.
● Google Home App: The main application for managing all devices and routines.
3.5. Security and Data Privacy
● Security: Google has strong mechanisms for account security (2-Step Verification,
etc.). Communication is encrypted.
● Data Privacy: This is Google's most debated aspect. Google collects data, including
voice commands and device usage data, to personalize services and (depending on
user settings) for ad targeting [1 5 ].
4. Home Assistant
4.1. System Overview
Home Assistant (HA) is an open-source, free, and local-first smart home platform. It is not
owned by a company; it is managed by a worldwide community of developers and users. It is
known for its power, flexibility, and customization, but it is a platform that requires technical
knowledge [1 6 ].

4.2. Technical Architecture and Topology
Home Assistant's architecture is fundamentally different from the other three:
● Self-Hosted: Home Assistant is not a cloud service. It is software that the user installs
on their own hardware (Raspberry Pi, mini-PC, etc.).
● Local-First Control: The platform's brain is this device in the user's home. All
automations, device communication, and data are processed and stored on the local
network by default. The entire system continues to run even if the internet is down
[1 6 ].
● Topology: All smart devices in the home connect directly to the server running the
Home Assistant software.
● Remote Access (Optional): Remote access is disabled by default. Users must enable
it themselves, either by using Nabu Casa or by manually setting up a VPN or a reverse
proxy.
4.3. Communication Protocols and Standards
Home Assistant is superior in protocol support:
● All Supported: It supports Wi-Fi, Bluetooth, Matter, and Thread.
● USB Dongle Support: Through inexpensive USB adapters (dongles), it can control
Zigbee and Z-Wave devices directly and locally [1 7 ].
● Integrations: With thousands (3000+) of official and community-developed
"integrations," it can communicate with almost any device or service imaginable.
4.4. Functionality and Feature Set
● Unlimited Customization: Its greatest strength. The interface and automations are
completely customizable.
● Powerful Automation Engine: Allows for the creation of highly complex and
conditional automation scenarios.
● Add-ons: Dozens of additional services can be installed on the Home Assistant
setup (e.g., AdGuard, Node-RED).
● Local Voice Assistant (Assist): It has its own local voice assistant named "Assist,"
which does not rely on the cloud.
● Learning Curve: This flexibility comes with a steep learning curve.
4.5. Security and Data Privacy
● Maximum Privacy: By default, no data leaves your home. Your data is not collected,
analyzed, or used for advertising by any company [1 6 ].
● User Responsibility: The security of the platform is entirely the user's responsibility.
5. Comparative Analysis of Platforms
The following table provides a detailed comparison of the four platforms based on critical
architectural and functional criteria utilizing the data gathered [ 5 ].

Feature Samsung
SmartThings
Apple
HomeKit
Google Home Home Assistant
5.1 Core
Architecture
Hybrid (Cloud +
Local)
Local-First Cloud-Centric Local (Self-Hosted)
5.1 Key Strength
Device
compatibility,
Samsung
ecosystem
Privacy,
Security,
Apple
ecosystem
Voice Assistant
(AI), Google
services
Customization,
Local control,
Flexibility
5.2 Setup
Difficulty
Easy / Medium Easy Very Easy Difficult
(Technical
knowledge
required)
5.3 Zigbee / Z-
Wave Support
Yes (with Hub) No (Bridge
only)
No (Bridge only) Yes (with USB
Dongle)
5.4 Matter /
Thread Support
Yes Yes
(Strong
support)
Yes
(Strong
support)
Yes
5.5 Data
Privacy
Model
Data
collected
(Service/Ad
s)
No data
collected
(Max
privacy)
Data
collected
(Service/Ad
s)
No data collected
(User control)
5.6 Offline
Functionality
Partially (with
Edge Drivers)
Yes (Fully) Very Limited Yes (Fully)
5.1. Core Architecture and Key Strengths
The fundamental design philosophy varies significantly across platforms. Samsung
SmartThings employs a hybrid approach, balancing cloud connectivity with local execution
via Edge Drivers. Apple HomeKit and Home Assistant prioritize a "Local-First" architecture,
ensuring that automation logic runs on a local hub to maximize reliability and privacy. In
contrast, Google Home remains largely "Cloud-Centric," leveraging its server-side processing
power to deliver superior AI and voice assistant capabilities [ 6 ].

5.2. Setup Difficulty and User Experience
Google Home offers the most accessible entry point with a "Very Easy" setup process.
Apple HomeKit follows a similarly streamlined "Easy" setup. SmartThings presents a
"Medium" difficulty curve due to its extensive features. Conversely, Home Assistant is
categorized as "Difficult" because it requires self-hosting and technical knowledge [1 6 ].

5.3. Legacy Protocol Support (Zigbee & Z-Wave)
Support for legacy local protocols is a key differentiator. SmartThings (via its Hub) and
Home Assistant (via USB Dongles) provide native support for Zigbee and Z-Wave devices.
Apple HomeKit and Google Home do not directly support these protocols; they require third-
party bridges [ 7 ], [1 7 ].

5.4. Matter and Thread Support
Reflecting the industry's shift toward standardization, all four platforms—SmartThings,
HomeKit, Google Home, and Home Assistant—have adopted the Matter standard and Thread
networking. This ensures future-proof compatibility and reduces the reliance on proprietary
bridges [ 9 ].

5.5. Data Privacy Models
Privacy approaches are strictly divided. Apple HomeKit and Home Assistant operate on a
"No Data Collection" model, processing data locally to ensure maximum user privacy. On the
other hand, Samsung SmartThings and Google Home operate on a service-based model where
usage data is collected to personalize services and, in some cases, for advertising purposes
[1 5 ], [1 8 ].

5.6. Offline Functionality
Reliability during internet outages is critical. Apple HomeKit and Home Assistant provide
full offline functionality. SmartThings offers partial offline support through its Edge Drivers.
Google Home has very limited offline capabilities [1 4 ].

6. Conclusion and Evaluation
This technical review of the four leading smart home platforms (SmartThings,
HomeKit, Google Home, and Home Assistant) clearly reveals the fundamental design
philosophies and architectural trade-offs to consider when developing a new smart home
project. Instead of selecting the "best" platform, the primary lesson from this review is that
each platform uses technology with a different strategy to meet a specific user need.
From a project development perspective, the key examples that can be taken from these
systems are:
The Architectural Dilemma: Local vs. Cloud?
Apple HomeKit and Home Assistant are the strongest examples
of a "local-first" architecture. This approach offers critical
advantages such as reliability (continuing to function during
internet outages) and privacy (user data stays in-house). If
reliability and privacy are priorities for your project, the "Home
Hub" (Apple) or self-hosted (HA) models should be studied.
Google Home demonstrates the power of the "cloud-centric"
approach. It leverages the cloud for advanced AI (Google
Assistant), complex third-party integrations, and scalability.
However, this comes with internet dependency and data privacy
concerns.
Samsung SmartThings offers a pragmatic path by presenting a
"hybrid" model between these two worlds. Its steps toward
local control with "Edge Drivers" serve as a valuable example of
how a balance can be struck between the flexibility of the cloud
and the speed of local processing.
Interoperability Strategy:
A project's success depends on how many devices it can
communicate with. SmartThings ' embrace of legacy protocols like
Zigbee and Z-Wave has been key to gaining a large market share.
Home Assistant proves that the philosophy of "integrating
everything" (3000+ integrations) is technically possible
through the power of its open-source community.
Apple's strong support for the Matter standard is the most
significant trend indicating the industry's evolution away from
"walled gardens" and toward a common language. A new project
must consider Matter as a foundational element for protocol
support.
User Experience and Data Privacy:
These platforms show that user experience (UX) is more than just
an interface. For Google Home , the UX is voice and AI. For
Apple HomeKit , the UX is security, privacy, and ecosystem
(Siri/iPhone) integrity. For Home Assistant , the UX is unlimited
customization and control.
Our project's approach to data privacy will be a fundamental
architectural decision. HomeKit's end-to-end encryption and local
analysis model (Secure Video) provides the best example of how to
design a "privacy-first" product, while Google represents the value
of data-driven personalization.
Requirements
This report outlines the architectural design and agile requirements for an IoT-Based Smart
Home System. The project aims to provide a secure, efficient, and user-friendly environment
by integrating environmental monitoring, automated resource management, and AI-
supported security features. Before detailing the specific user stories, the high-level
interaction between the system and external entities is illustrated below.

As illustrated in Figure 1, the system acts as a central hub connecting the Home
Environment (Sensors/Actuators) with the Cloud Services and Users (Remote
Residents/Admins). While local sensors feed data directly to the central unit, critical alerts
and configurations are managed via secure cloud communication channels.

1. Agile Development Methodology and User
Profiles
1.1 User Personas and Stakeholder Analysis
Key user profiles (personas) that will guide the system's architectural decisions have
been defined in line with the project goals:
Persona 1: The Remote Resident
o Definition : An end-user concerned about home security and environmental
conditions, familiar with technology but unwilling to deal with complex setups.
Figure 1 IoT Smart Home System Context Diagram
o Expectation : Prefers "peace of mind" over a passive data stream. Wants to be
disturbed only in critical situations (fire, flood, burglary).

o Interaction : Receives instant notifications via the mobile app and accesses live
camera feeds.

Persona 2: The Student/Admin (System Administrator)

o Definition: The technical expert developing the Smart Home System project and
configuring the system.

o Expectation : Accessibility to low-level operations such as sensor calibration,
Artificial Neural Network (ANN) model training, and database management.

o Interaction: Maintains the system via the Web-based Management Panel and
hardware interfaces

2. Functional Requirements (Agile Epics and
User Stories)
Figure 2 Comprehensive User Use Case Diagram and Requirement Map
The following diagram serves as a functional map of the system from the user's
perspective. Each node in the diagram corresponds to a specific User Story detailed in
the subsequent sections. Figure 2 details the interactions between the actors (Home
Owner, User) and the system modules. The numbers assigned to each use case (e.g., 1.1,
1.2, 4.1) directly correspond to the subsection headers below, serving as a navigational
guide.

2.1. Epic 1: Environmental Monitoring and Critical
Hazard Management
This epic covers the system's fundamental IoT capabilities. The goal is continuous
analysis of the home environment and immediate reporting of hazardous situations.

User Story 2.1.1: Tracking Climate Periodically
Story: As a resident, I want to see the temperature and humidity values of my home so
that I can ensure a comfortable living space.

Technical Detail : Sensor data is a continuous stream. However, sending data every
second increases network traffic and database load. Therefore, a "polling" mechanism
must be established.
Acceptance Criteria :
o The system must read temperature and humidity sensors at a configurable interval
(e.g., every 30 seconds).

o The read data must be packaged in JSON format with a timestamp and transmitted to
the Cloud Server via HTTP POST or MQTT Publish.

o Web and Mobile interfaces must display the latest data with less than 1 minute of

latency.
User Story 2.1.2: Detecting Emergency Hazards (Fire and Flood)
Story : As a user, I want to be notified immediately of smoke or water leaks so I can
take urgent action to protect my property.
Technical Detail : Periodic reading is insufficient for emergencies. Therefore, an
"Interrupt-based" architecture must be used.
Acceptance Criteria:
o When the smoke or water sensor's digital output reaches the "HIGH" level, the system
must interrupt the normal loop and trigger an "Emergency Event".

o This event must be transmitted to the server with a high-priority flag, and processing time
must not exceed 5 seconds.

o A "Critical Alert" must be sent to the mobile application, designed to be noticeable even if
the phone is on silent.

User Story 2.1.3: Displaying Centralized Local Dashboard
Story: As a resident, I want a dedicated, always-on wall display to view real-time sensor
data and system status, allowing me to monitor the environment at a glance without needing
to locate and unlock my mobile phone.

Technical Detail : This involves integrating a touch-enabled LCD screen (e.g., 7-inch
Touch Display) directly with the Raspberry Pi via DSI or HDMI. The software will run a
lightweight local GUI optimized for touch interaction.
Acceptance Criteria:
o The screen must provide a consolidated view of Temperature, Humidity, and Security
Status (Armed/Disarmed).

o The interface must include a visual indicator (e.g., red blinking border) alongside the
buzzer during critical events.

o Users must be able to silence active alarms or toggle security modes directly through the
touch interface.

User Story 2.1.4: Monitoring Pet Resource Automatically
Story: As a pet owner, I want to track the weight of food and water bowls to receive alerts
when they are running low, ensuring my pet's needs are met even when I am busy.

Technical Detail : This requires integrating a Load Cell sensor with an HX711 amplifier
module to the Raspberry Pi. The system must filter signal noise and convert the analog
weight data into a digital percentage value.
Acceptance Criteria:
o The system must be able to calibrate the empty and full weights of the containers.

o When the weight drops below a user-defined threshold (e.g., 10%), a "Low Food/Water"
notification must be sent to the mobile app.

o To prevent notification fatigue, the alert should only be repeated after a specific cooldown
period (e.g., 4 hours) if not refilled.

User Story 2.1.5: Monitoring Lights for Energy Efficiency
Story: As an energy-conscious resident, I want to monitor the status of lights remotely and
receive notifications if they are left on for an extended period, helping me reduce
unnecessary electricity consumption.
Technical Detail: This involves using LDR (Light Dependent Resistor) sensors or
noninvasive current sensors (CT) to detect the state of lighting circuits. The backend must
implement a timer logic that starts when a light is detected as "On" and triggers an alert if
the duration exceeds a configured threshold.
Acceptance Criteria:
o The mobile app must display the real-time status (On/Off) of monitored lights.

o The system must track the duration of the "On" state in real-time. o If a light remains
active longer than a user-defined limit (e.g., 4 hours), an "Energy Waste Alert" notification
must be pushed to the user.

User Story 2.1.6: Monitoring Plant Health
Story: As a plant enthusiast, I want the system to monitor the soil moisture of my indoor
plants and notify me when they need watering, preventing both dehydration and
overwatering.
Technical Detail: This utilizes Capacitive Soil Moisture Sensors connected via an Analog-
to-Digital Converter (ADC) or digital GPIO pins. The system reads the voltage, maps it to a
percentage (0-100%), and compares it against plant-specific thresholds.
Acceptance Criteria :
o The dashboard must display the current moisture percentage of the monitored plant.

o A notification ("Time to Water: Living Room Fern") must be triggered when moisture
drops below a critical level (e.g., 30%).

o To prevent false positives or spam, the alert should only be sent if the low moisture level
persists for more than 10 minutes.

2.2. Epic 2: AI-Supported Security and System Automation
This section defines the system's internal automated tasks and "active security" features. The
diagram below illustrates how the System acts as an autonomous actor to execute these tasks

Figure 3 highlights the backend processes initiated by the System itself, specifically focusing
on Security (2.x), Communication (3.x), and automated tracking (1.x Series).

Figure 3 System Use Case Diagram.
User Story 2.2.1: Capturing Motion-Sensitive Images
Story: The system should activate the camera only when motion is detected, protecting my
privacy and saving disk space.
Technical Detail: While cloud-focused systems can stream continuously, local triggering
is more efficient in terms of bandwidth and privacy.
Acceptance Criteria:
o The signal from the PIR sensor must wake up the camera module.

o Within 500 milliseconds of triggering, the camera must capture a photo or record a short
video (5-10 seconds).

o The captured image must be buffered in RAM for processing.

User Story 2.2.2: Classifying Authorized and Unauthorized Persons
Story: As a resident, I want the system to distinguish between family members and
strangers so I am not disturbed by false alarms.
Technical Detail: Project goals require "identity detection" beyond motion. This
necessitates the use of libraries like OpenCV or TensorFlow Lite.
Acceptance Criteria:
o The captured image must be fed into a pre-trained Face Recognition or Human Detection
model.

o The detected face must be compared with the registered "Residents" database.

o If the match rate is below a certain confidence threshold (e.g., 70%), the event must be
labeled as "Unauthorized Intrusion".

o For authorized persons, only an "Entry Log" is kept, while for unauthorized persons, a
security alarm is triggered.

2.3. Epic 3: Data Management and Cloud Backend
The cloud layer, the "Central Nervous System," ensures data persistence and accessibility as
referenced in Use Case 3.1 and 3.2.

User Story 2.3.1: Communicating via Secure API
Story: As a system admin, I want sensor data to reach the server via a secure channel.
Technical Detail: Literature review shows that significant vulnerabilities in early smart
home systems stemmed from unencrypted communication.
Acceptance Criteria:
o The cloud application must offer RESTful API endpoints.

o All data traffic between the IoT module and the server must be encrypted using the
HTTPS/TLS (Transport Layer Security) protocol.

o API requests must include API Key or Token-based authentication to prevent unauthorized
data entry.

User Story 2.3.2: Viusalizing Historical Data
Story: As a user, I want to view historical temperature changes in graphs.
Acceptance Criteria:
o The database must store sensor readings using time-series logic.

o The web interface must allow the user to select a date range and visualize the data in that
range as a line chart.

2.4. Epic 4: Remote Access and Mobile Experience
The interface layer ensures the user remains connected to their home at all times.

User Story 2.4.1: Delivering Push Notifications
Story: As a mobile user, I want to be notified of critical events in my home even if the
application is closed.
Technical Detail: Constantly checking the app is impractical. Server-client interaction
must be provided using services like cloud messaging applications.
Acceptance Criteria:

o When the server detects a critical event (Fire, Intruder), it must send a notification request
to the CM service.

o The mobile app must receive this notification and provide audible and vibrating alerts to
the user. o The notification content must clearly state the type and time of the event (e.g.,
"ATTENTION: Smoke Detected in Living Room - 14:30").

User Story 2.4.2: Managing Notification Preferences
Story: As a Remote Resident, I want to be able to turn push notifications on or off at any
time, so that I can avoid being disturbed when I am already at home or busy.
Technical Detail: A boolean flag must be stored in the user's profile in the database. The
backend service must check this flag before triggering the CM service.
Acceptance Criteria:
o The mobile application must have a "Settings" tab with a toggle switch for notifications.

o Toggling the switch must send an API request to update the user's profile in the database.

o If the user disables notifications, the server must suppress the CM request even if a motion
event is detected.

User Story 2.4.3: Granting Access Permissions
Story: As a Home Owner, I want to register family members and trusted guests into the
system database, granting them "authorized" status so that the security system recognizes
them and does not trigger a false intruder alarm.
Technical Detail: This functionality acts as the data entry point for the AI module defined
in User Story 2.2.
The mobile application must provide an interface to upload a face image or capture a new
photo.
This image is sent to the backend, where a face embedding (vector representation) is
generated and appended to the allowed_faces database or serialized file (e.g., pickle).
Acceptance Criteria:
o The mobile app must include a "Manage Residents" or "Add Person" screen. o The user
must be able to assign a name/label to the captured face.

o Upon saving, the system must update the AI model's reference list immediately.

o The system must confirm that the new person is successfully recognized as "Authorized"
in the next camera detection cycle.

3. Non-Functional Requirements (NFRs - Quality
Attributes)
This section defines the system’s operational standards, constraints, and quality attributes,
ensuring the solution is not only functional but also robust, usable, and secure.

3.1. Security and Privacy
Security : As the system handles sensitive data within a private residence, security is
paramount.

Data Encryption : All data traffic between the IoT module, the Cloud Server, and the
Mobile Application must be encrypted using HTTPS/TLS 1.2+ (Transport Layer Security).
Data Storage: Sensitive user information (e.g., passwords, API keys) must be stored in the
database using strong hashing algorithms (e.g., bcrypt or Argon2), never in plain text.
Visual Privacy: To protect resident privacy, continuous video streaming must be disabled
by default. Camera footage should only be processed locally on the Raspberry Pi, and only
images related to a triggered security event shall be uploaded to the cloud.
3.2. Reliability and Availability
Resilience : The system must maintain core functionality even during infrastructure failures.

Offline Operation (Graceful Degradation): In the event of an internet outage, the system
must not fail completely. The Edge Node (Raspberry Pi) must continue to process sensor
data locally, trigger the local buzzer for fire alarms, and buffer captured security images to
the local SD card.
System Recovery : In the event of a power failure, the IoT system must reboot and restore
all monitoring services (sensors and API listeners) automatically within 90 seconds of power
restoration.
Automatic Reconnection: If the Wi-Fi connection is lost, the system must attempt to
reconnect automatically every 30 seconds until connectivity is restored, without requiring
manual user intervention.
3.3. Performance and Latency
Responsiveness: The system must react to critical physical events faster than human reaction
time.

Local Response Time: For life-critical events (Fire/Flood), the latency between the sensor
detecting the hazard and the local alarm (buzzer) sounding must be under 100 milliseconds.
Notification Latency: Assuming a stable internet connection (4G/Wi-Fi), the end-toend
latency for a "Critical Alert" (from sensor trigger to the user receiving a Push Notification)
must be under 5 seconds.
AI Inference Speed: The face recognition algorithm running on the Raspberry Pi must
process a captured image frame and return a classification result (Authorized/Unauthorized)
within 3 seconds to ensure timely logging of intruders.
3.4. AI Accuracy and Precision
Intelligence: The automated decision-making modules must meet minimum accuracy
thresholds to prevent false alarms.

Classification Accuracy: The "Authorized/Unauthorized Person Classification" module
must achieve a True Positive Rate (TPR) of at least 85% under normal indoor lighting
conditions.
False Positive Mitigation: The system must have a False Positive Rate (FPR) of less than
5% to prevent user "notification fatigue" caused by identifying family members as intruders.
Sensor Precision: Temperature readings must be accurate within ±1°C, and humidity
readings within ±5%, ensuring reliable environmental data for the user.
3.5. Usability and User Experience
Accessibility: The system is designed for the "Remote Resident" persona, who prioritizes
ease of use over technical complexity.

UI Responsiveness: The Mobile and Web interfaces must provide visual feedback (e.g.,
loading indicators, state changes) within 200 milliseconds of any user interaction (tap/click)
to ensure a smooth experience.
Learnability: A new user with no prior technical knowledge must be able to perform
primary tasks (e.g., viewing the camera feed, silencing an alarm) within 2 minutes of first
using the application.
Error Handling: In case of a sensor failure or network error, the system must display user-
friendly messages (e.g., "Living Room Sensor is offline") rather than technical error codes.
3.6. Scalability and Sustainability
Future-Proofing: The architecture must support future growth and comply with sustainability
goals.

Data Retention Policy: To manage storage on the Raspberry Pi's SD card, the system must
implement a First-In-First-Out (FIFO) policy. When local storage usage exceeds 90%, the
oldest non-critical logs and images must be automatically deleted.
Modular Architecture: The software must adhere to Object-Oriented Programming (OOP)
principles. Adding a new sensor type (e.g., a Light Sensor) should require creating a new
class inheriting from the base "Sensor" class without modifying the core engine.
Sustainability (SDG 9): The system infrastructure must be capable of logging energy
consumption metrics (as part of the Extended Scope) to support future efficiency analysis
features.
System Architecture
The purpose of this document is to outline the architectural design and system
components of the proposed IoT-Based Smart Home System. This system aims to
provide a secure, efficient, and user-friendly home monitoring environment by
integrating environmental sensing, automated resource management, and AI-supported
security features.

The design prioritizes an "Edge-First" approach. Critical triggers and initial processing
are performed locally on the device to ensure reliability and privacy, while cloud
services are leveraged for heavy processing (AI Face Matching), data persistence, and
remote accessibility.

The high-level system architecture consists of the following key nodes:

● Edge Layer (Raspberry Pi 5): The Raspberry Pi 5 operates as the local edge
processing unit, running the Sensor Driver Service and Rule Engine. It
communicates with the cloud over Wi- Fi using secure protocols (HTTPS/MQTT).
The system is designed to support graceful degradation , ensuring that critical local
alarms remain functional even when internet connectivity is unavailable.
● Cloud Backend: The cloud backend hosts the REST API and database
services. It is responsible for centralized state management, data
persistence, and triggering push notifications via an external notification
provider when critical events occur.
● Client Applications: The Web Dashboard and Mobile Application fetch data from
the cloud node via API requests, allowing users to view real-time status and
historical logs.

1. Design of Home Controller
The hardware architecture is centered around a Edge Layer (Raspberry Pi 5)
single- board computer, acting as the main home controller and edge processing unit. The
system integrates various sensors and actuators through specific digital and analog
interfaces to minimize latency.

● Main Controller (Raspberry Pi 5): Selected for its high processing power,
enabling local sensor management and preliminary event detection.
● Vision Module: A Raspberry Pi Camera Module connected via the CSI
(Camera Serial Interface) port to provide high-bandwidth video data for the
surveillance system.

● Environmental Sensors: The DHT11 (Temperature & Humidity) and MQ- 2 (Gas
& Smoke) sensors are connected via GPIO pins to facilitate climate tracking and
emergency detection.
● Resource Monitoring: A Load Cell paired with an HX711 Amplifier Module
connects to digital pins to precisely measure weight for the "Automated Pet
Resource Monitoring" feature.
● Storage: A high-speed microSD Card (64GB) is utilized for the OS, local logs,
and image buffering during offline operation (Graceful Degradation)
2.Software Architecture Design
The software architecture follows a modular 4 - Tier Layered Architecture pattern to
ensure separation of concerns, scalability, and maintainability.
2.1 Layer Decomposition
Layer 1: Presentation (User Interfaces)
This layer handles user interactions via the Mobile Application and Web
Dashboard. It communicates solely through API calls, ensuring a stateless and responsive
user experience. It allows users to view dashboards, receive notifications, and send manual
commands (e.g., "Open Camera").

Figure 4 Design of Home Controller
This figure illustrates a real-time security notification generated by the mobile application
of the smart home system. When motion is detected and the captured individual cannot be
identified as an authorized user, the system triggers an alert labeled “Unknown Person
Detected.” The notification provides a brief description of the event, enabling the user to
take immediate action through the application.

Figure 5 Mobile Application Security Notification
This figure presents the main dashboard of the mobile application used in the smart home
system. The interface displays real-time environmental data, including temperature and
humidity levels, along with a live camera feed for continuous surveillance. Additionally,
the dashboard provides status information for automated resource monitoring features
such as pet food level and plant water level. Visual indicators and alerts are used to notify
the user when critical thresholds are reached, enabling timely user intervention and
efficient home management.

Figure 6 Mobile Application Dashboard Interface
Figure 7 Web Dashboard Interface of the Smart Home System
This figure illustrates the web-based dashboard of the IoT smart home system. The
interface provides a centralized view of real-time environmental data, including
temperature and humidity levels, along with a live camera stream for continuous
monitoring. In addition, the dashboard displays recent system alerts such as fire
detection, intrusion events, and low resource warnings. Interactive controls and visual
indicators enable users to acknowledge alerts, monitor system status, and manage home
resources efficiently through a single web interface.

Layer 2: Security
This layer is responsible for user authentication during application login. Users are
required to provide valid credentials (e.g., username and password) before accessing the
system. Once authenticated, secure communication between the client applications and
the backend is established using HTTPS/TLS. The security layer ensures that only
authorized users can access system functionalities, while all business logic operations
are executed after successful login verification.

Layer 3: Business Logic (Core Modules)
This is the core of the system where data processing occurs. To maintain a clean architecture
and clear separation of duties, the functional requirements are grouped into four distinct
handler modules:
Climate Monitoring Service: Handles periodic reading and logging of temperature and
humidity data.
Pet Resource Manager: Manages the monitoring of food/water bowls and triggers alerts for
low levels.
Emergency Response Manager: Dedicated to interrupt-based critical tasks like "Detecting
Fire and Flood" to ensure immediate local feedback.
Surveillance & Intrusion Analysis Engine: A comprehensive security engine that handles
the single-loop logic for motion capture, cloud-based face recognition, and the "Frequency
Analysis" of unknown visitors.
Layer 4: Data & Integration
This layer manages persistence via the Cloud Database (storing user profiles, logs,
and safe/non-safe face vectors) and handles third-party integrations, such as the External Push
Notification Provider.
2. Detailed Module Design & Sequence Flows
This section details the internal algorithms, logic flows, and interaction sequences for
the key functions defined in the Business Logic Layer.
2.1 Climate Monitoring Service
Addresses Requirements: [Req. 2.1.1]
Since continuous data streaming places unnecessary load on the network, this module
utilizes a "Polling Mechanism".
● Logic: The system wakes up at a configurable interval (default: 30s), reads the DHT11 sensor
via GPIO, validates the data range, and transmits the packaged JSON payload to the Cloud
Backend.
● Sequence: The interaction flow for periodic climate tracking is illustrated below.

Figure 8 Temperature & Humidity Sequence Diagram
2.2 Pet Resource Manager
Addresses Requirements: [Req. 2.1.4]
This module focuses on ensuring pet safety by tracking resource availability.
● Logic: The system reads the Load Cell (via HX711). The analog weight is converted to a
percentage (0-100%). If Weight < Threshold (10%), a "Low Resource Event" is flagged.
It includes a cooldown timer to prevent notification fatigue (e.g., only one alert every 4
hours).
● Sequence: The flow for weight measurement and alert triggering is shown below.

Figure 9 Pet Food Monitoring Sequence Diagram
2.3 Emergency Response Manager
Addresses Requirements: [Req. 2.1.2] & [Req. 3.2]
Unlike the polling mechanism, emergency sensors operate on an Interrupt-based
Architecture to ensure immediate response.
● Logic: When the Gas/Smoke sensor triggers, the main loop is interrupted. The Edge Node
immediately triggers the local buzzer (Graceful Degradation) while simultaneously sending a
high-priority alert to the Cloud Backend for push notifications.
● Sequence: The flow from detection to user notification is shown below.

Figure 10 Fire Detection Sequence Diagram
2.4 Surveillance & Intrusion Analysis Engine
Addresses Requirements: [Req. 2.2.1], [Req. 2.2.2], [Req. 2.4.3]
The security system operates on a Continuous Single-Loop Mechanism to avoid
complex multi-threading issues and ensure stability.
● Logic Flow:

Sequential Check: The system first checks for a "Manual Stream Request" from the app. If
none, it checks the PIR Motion Sensor.
Capture & Filter: If motion is detected, images are captured. A local lightweight model
checks for human presence.
Cloud Identification: Images are sent to the cloud. The AI compares the face against the
"Safe User" database.
Frequency Analysis: If unauthorized, the system checks visit history (Frequency Analysis)
and notifies the user with a visit count, asking for verification.
● Sequence: The complete flow from motion detection to AI classification and user notification
is detailed below.
Figure 11 Classifying Authorized/Unauthorized Persons Data-flow Diagram

This figure illustrates the data flow and decision-making process of the
surveillance and intrusion analysis module in the smart home system. The workflow
begins with either a manual camera request from the user or motion detection by
sensors. Captured images are initially processed on the edge device (Raspberry Pi) to
detect human presence. If a person is identified, the images are forwarded to the cloud
for face recognition by comparing them with registered safe user profiles stored in the
database. When no match is found, the system performs a frequency analysis to
determine whether the individual has been previously detected, increments a visit
counter if necessary, and notifies the user accordingly. Based on user feedback, the
detected individual may later be classified as a safe user, allowing the system to update
stored profiles and improve future recognition accuracy.

3. Database Design
The database is designed to support user authentication, device management,
sensor data storage, and event logging for the IoT-based smart home system. A
centralized cloud database is used to ensure data persistence, scalability, and reliable
access from both the mobile application and the web dashboard.

3.1 User Authentication Data
User-related data is stored to support secure application access. Basic user
information and encrypted credentials are maintained in the database. Upon successful
login, a session record is created to manage authenticated access. This structure ensures
that only authorized users can interact with the system and access device data.

3.2 Device and Sensor Data
Each registered user may own one or more smart home devices. Devices are
associated with multiple sensors, such as temperature, humidity, gas, motion, and load
sensors. Sensor readings are stored as time-stamped records to enable real-time
monitoring as well as historical data analysis through the client applications.

3.3 Event and Alert Management
System events, including emergency situations (e.g., fire detection), intrusion
detection, and low resource levels, are recorded as alerts in the database. Alerts are
linked to both the originating device and the corresponding user. This allows users to
review recent alerts, acknowledge notifications, and track past incidents through the
dashboard interfaces.

3.4 Surveillance Data
Camera-based security events are logged to support the surveillance and
intrusion analysis features. Captured images and detection results are associated with
camera events. Authorized user face profiles are stored separately and referenced
during cloud-based face recognition processes to distinguish known users from
unknown individuals.

3.5 Design Considerations
The database design follows a relational structure with clearly defined
relationships between users, devices, sensors, and events. This approach ensures data
integrity, simplifies access control after authentication, and supports future system
extensions without requiring major architectural changes.

Figure 9 Entity-Relationship (ER) Diagram of the Smart Home System Database
This figure illustrates the Entity-Relationship (ER) diagram of the database designed for
the IoT-based smart home system. The diagram presents the core entities, including
users, devices, sensors, camera events, and alerts, along with their relationships and
cardinalities. Primary and foreign keys are used to ensure data integrity, while optional
relationships support scenarios such as unidentified individuals in camera-based
surveillance. The database structure supports user authentication, real-time monitoring,
event logging, and alert management in a centralized cloud environment.

4. Conclusion
This document presented the architectural design and system components of an IoT-
based smart home system that integrates environmental monitoring, automated resource
management, and AI-supported security features. By adopting an edge-first approach, the
system ensures reliable local operation, reduced latency, and improved privacy while
leveraging cloud services for data persistence, advanced processing, and remote
accessibility.

The proposed layered architecture provides clear separation of concerns between user
interfaces, security, business logic, and data management. Core functionalities such as climate
monitoring, emergency response, resource tracking, and surveillance are designed as modular
services, enabling scalability and ease of future extension. The surveillance and intrusion
analysis workflow combines edge-based processing with cloud-based face recognition to
enhance system responsiveness and security awareness.

The database design and data flow structures support secure user authentication, real-
time monitoring, event logging, and alert management in a centralized manner. Overall, the
proposed design offers a robust and flexible foundation for a smart home system and can be
extended in future work to include additional sensors, automation rules, and advanced
analytics.

References
[1] Albany, M. (2022). A review: Secure Internet of Thing System for Smart Houses.
[Conference/journal details].

[2] Bouchabou, D., Nguyen, S. M., Lohr, C., Leduc, B., & Kanellos, I. (2021). A Survey of Human
Activity Recognition in Smart Homes Based on IoT Sensors Algorithms: Taxonomies, Challenges,
and Opportunities with Deep Learning. arXiv preprint arXiv:2111.04418.

[3] Sutar, P., Sarkar, S., Tagare, A., & Pawar, A. (2024). A Review on IoT-Enabled Smart Homes
Using AI. IEEE ICCCNT.

[4] Zia, M. F., Siddiqua, M., Ouameur, M. A., Bagaa, M., & Al Turjman, F. (2025). Securing the
Future: A Survey on Smart Home Security in IoT-Integrated Smart Cities. Advances in Networks,
12 (1), 1–18.

[5] R. Harper, "The Connected Home: A Comparative Review of IoT Ecosystems," International
Journal of Smart Home Technology, vol. 12, no. 3, pp. 45-58, 2023.

[6] J. Smith and A. Doe, "Architectural Trade-offs in Modern Smart Home Platforms: Cloud vs.
Edge Computing," IEEE Internet of Things Journal, vol. 10, no. 14, 2024.

[7] Samsung Developers, "SmartThings Architecture and Hub Connectivity," Samsung Developer
Documentation, 2023. [Online]. Available: developer.smartthings.com.

[8] Samsung SmartThings, "Edge Drivers: Moving Intelligence to the Edge," Technical White
Paper, Oct. 2022.

[9] Connectivity Standards Alliance (CSA), "The Matter Standard: Universal IP-based Connectivity
for Smart Home," CSA Specification Version 1.2, 2023.

[10] Samsung Knox, "Security Solutions for IoT and Smart Home," Samsung Enterprise Security,

[11] Apple Inc., "Platform Security Guide: HomeKit Security and Privacy," Apple Support
Documentation, May 2024.

[12] Apple Inc., "HomeKit Secure Video: Local Analysis and Encryption Standards," Apple
Developer Archive, 2023.

[13] Google Nest, "Google Home Platform Architecture: Cloud-to-Cloud Integrations," Google
Developers, 2023. [Online]. Available: developers.home.google.com.

[14] Google Developers, "Building for Matter on Google Home," Google I/O Technical Sessions,

[15] M. Johnson, "Data Collection and Privacy in Voice Assistant Ecosystems," Journal of
Cybersecurity and Privacy, vol. 5, no. 1, pp. 112-129, 2023.

[16] Home Assistant, "The State of the Open Home: Local Control and Privacy," Home Assistant
Official Documentation, 2024. [Online]. Available: home-assistant.io.

[17] P. Schiestl, "Zigbee and Z-Wave Integration in Open Source Home Automation," Proceedings
of the Open Source IoT Conference, 2022.

[18] Electronic Frontier Foundation (EFF), "Privacy Analysis of Consumer IoT Devices," Tech
Policy Report, 2023.