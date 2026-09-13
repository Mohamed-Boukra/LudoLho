# LudoLho 🎲

This repository contains a customized Ludo game implemented using Flutter. 
*Note: This project is a modified version based on the original open-source project by [Gulshid/Ludo-Game](https://github.com/Gulshid/Ludo-Game).*

## Table of Contents 📚

- [About the Project](#about-the-project)
- [New Features & Rules](#new-features--rules)
- [Tech Stack](#tech-stack)
- [Installation](#installation)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)
- [Footer](#footer)

## About the Project 🚀

LudoLho brings the beloved classic Ludo board game to life with a modern, cross-platform implementation using the Flutter framework. While keeping the core mechanics intact, this version has been extensively customized with fresh UI elements, new house rules, and quality-of-life improvements to make the game more engaging and competitive!

## New Features & Rules ✨

We've built upon the original game by adding several exciting new features:
- **Player Customization:** You can now input custom names for each player before the match begins.
- **Turn Timer:** Added a 15-second turn timer to keep the game moving fast. If you run out of time, your turn is skipped!
- **Dice Statistics Panel:** A brand new UI panel that tracks every roll for each player. It features a polished, colored dice UI showing exact dice frequencies.
- **Enhanced UI Layout:** The active player's dice and turn banner have been repositioned outside the board to prevent overlapping with tokens in the yard.
- **Mandatory Capture (House Rule):** Options for "Eat All" behavior when multiple identical opponent tokens are stacked.
- **Final Stretch Constraint (House Rule):** A strict rule that prevents players from moving a 6 in the final stretch (between their home and the previous color's home).
- **Score Ranking System:** Players are now ranked at the end of the game based on their score (calculated dynamically based on captures and deaths). "Play for full standings" is now on by default!
- **Sound & Haptics:** Polished haptic feedback during captures and smooth sounds on dice rolls.

## Tech Stack 💻

- **Language:** Dart
- **Framework:** Flutter

## Installation 🛠️

To get a local copy up and running, follow these steps:

1.  **Clone the repo:**
    ```bash
    git clone https://github.com/Mohamed-Boukra/LudoLho.git
    cd LudoLho
    ```

2.  **Install Flutter:**
    If you don't have Flutter installed, follow the official installation guide for your operating system:
    [Flutter Installation Guide](https://docs.flutter.dev/get-started/install)

3.  **Get Flutter Dependencies:**
    Run the following command to download all required packages:
    ```bash
    flutter pub get
    ```

4.  **Run the Application:**
    You can run the application on your preferred platform (e.g., Android, iOS, Web, Desktop).
    ```bash
    flutter run
    ```

## Usage 🎮

This project serves as a complete implementation of the Ludo game with custom rules.

**How to Play:**
1.  Launch the application.
2.  Start the game on the setup screen where you can choose colors, type custom names, and toggle House Rules.
3.  Roll the dice within the 15-second timer.
4.  Be strategic! You can view the Dice Statistics panel at any time to see who is getting the luckiest rolls.
5.  The objective is to get all your tokens to the home base while capturing opponents to rack up a high score.

## Project Structure 📁

The project follows a standard Flutter project structure:

```
LudoLho/
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
├── lib/
│   ├── constants/
│   ├── models/
│   ├── providers/
│   ├── screens/
│   ├── services/
│   └── widgets/
├── test/
├── pubspec.yaml
└── README.md
```

## Contributing 🤝

Contributions are welcome! If you have suggestions for improving this project, please fork the repository and create a pull request. Any contributions you make are greatly appreciated.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## License 📄

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Contact 📧

Mohamed Boukra - mohamoha2006d@gmail.com

Project Link: [https://github.com/Mohamed-Boukra/LudoLho](https://github.com/Mohamed-Boukra/LudoLho)

## Footer 👋

Feel free to star ⭐, fork 🍴, and follow the repository and author for updates!

--- 
© 2026 Mohamed Boukra | [LudoLho](https://github.com/Mohamed-Boukra/LudoLho)