<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a id="readme-top"></a>
<!--
*** Thanks for checking out the Best-README-Template. If you have a suggestion
*** that would make this better, please fork the repo and create a pull request
*** or simply open an issue with the tag "enhancement".
*** Don't forget to give the project a star!
*** Thanks again! Now go create something AMAZING! :D
-->



<!-- PROJECT SHIELDS -->
<!--
*** I'm using markdown "reference style" links for readability.
*** Reference links are enclosed in brackets [ ] instead of parentheses ( ).
*** See the bottom of this document for the declaration of the reference variables
*** for contributors-url, forks-url, etc. This is an optional, concise syntax you may use.
*** https://www.markdownguide.org/basic-syntax/#reference-style-links
-->
[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]



<!-- PROJECT LOGO -->
<br />
<div align="center">
  <a href="https://github.com/JakeNeau/Jake-Neau-NixOS-Config">
    <img src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Nix_Snowflake_Logo.svg/250px-Nix_Snowflake_Logo.svg.png" alt="NixOS Logo" width="80" height="80">
  </a>

<h3 align="center">Jake Neau's NixOS Configuration</h3>

  <p align="center">
    A complete system configuration for my systems for use with the Nix package manager
    <br />
    <a href="https://github.com/jakeneau/Jake-Neau-NixOS-Config/issues/new?labels=bug&template=bug-report---.md">Report Bug</a>
    &middot;
    <a href="https://github.com/jakeneau/Jake-Neau-NixOS-Config/issues/new?labels=enhancement&template=feature-request---.md">Request Feature</a>
  </p>
</div>



<!-- TABLE OF CONTENTS -->
<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#core-design-principles">Core Design Principles/a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

[![Product Name Screen Shot][product-screenshot]](https://example.com)

This is my NixOS config to fully define any system I want to build. It include configuration for installing anything on a fully-featured system of mine, and the Home Manager configs for editing the configuration of installed software.
The usage of Home Manager in this project is to the point that some would call it dogmatic, but it makes all config reproducible between systems.
Right now, all configuration is un-modularized for simplicity with system configuration in `configuration.nix` and program configuration in `users/<user>/home.nix`, but in the future, these will be moved to adhere to the [Dendritic Pattern](https://github.com/mightyiam/dendritic).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Core Design Principles
- You should avoid all package managers except the Nix Package Manager
- Any program configuration that is possible through home manager should be done through home manager
- Prefer configuration implementations that fully utilize flakes


### Built With

* [![Nix][Nix.com]][Nix-url]
* [![NixOS][NixOS.com]][NixOS-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- GETTING STARTED -->
## Getting Started

This is intended to run on a NixOS system currently. Check back in the future for other environments like MacOS.

### Prerequisites

Install a NixOS from an [image file](https://nixos.org/download/). You will need a usb to flash the image onto, and a program to etch the image onto the USB. On *nix systems, dd can be used:
```sh
  dd if=/path/to/your/isofile of=/your/usb/disk bs=8M status=progress
```

### Installation

1. Clone the repo into `/etc/nixos/`
   ```sh
   cd /etc/nixos/
   rm -f configuration.nix
   git clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git
   mv ./Jake-Neau-NixOS-Config/* .
   rm -rf ./Jake-Neau-NixOS-Config
   ```
2. Copy keys.txt into secrets/ to decrypt password hash
3. Build the system
   ```sh
   sudo nixos-rebuild switch --flake /etc/nixos/
   ```

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- USAGE EXAMPLES -->
## Usage

The Niri Window Manager is used as the graphical interface for the system. Here are a few of the common shortcuts I have configured
- **Mod + Space**: Open application launcher
- **Mod + q**: Open new terminal emulator
- **Mod + c**: Close focused window

Additionally Fish is used for interactive shells. Here are some shortcuts I have configures with fish.
- **nrr**: Rebuild the system and push to GitHub with a default update status message
- **nr "message"**: Rebuild the system and push to GitHub with the message "message", a generation number is appended
- **nr**: Amend the last commit and push to GitHub with the same message byt a new generation number

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- ROADMAP -->
## Roadmap

- [ ] Get the Niri Window Manager looking nicer
  - [ ] Find a way to make screens take up an exactly 16:9 form factor on ultrawides
  - [ ] Re-enable [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) for beautiful bars and widgets
- [ ] Move repository to the Dendritic Pattern
- [ ] The hardware-configuration.nix file needs to be tracked despite being different on different machines, find a way around this for multi-environment
- [ ] Configure a cut-down environment for laptops
- [ ] Configure [Nix Darwin](https://github.com/nix-darwin/nix-darwin) environment for MacOS development
- [ ] Configure [NixOS-WSL](https://nix-community.github.io/NixOS-WSL/install.html) environment for Windows development (still debating this one)
- [ ] Update the README with SOPS specific instructions

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTRIBUTING -->
## Contributing

If you seriously want to spend your time contributing to someone else's system configuration, I'm not going to stop you. All contributions are welcome if they adhere to the principles of the project.

If you have a suggestion that would make this better, please fork the repo and create a pull request. You can also simply open an issue with the tag "enhancement"

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Top contributors:

<a href="https://github.com/jakeneau/Jake-Neau-NixOS-Config/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=jakeneau/Jake-Neau-NixOS-Config" alt="contrib.rocks image" />
</a>



<!-- LICENSE -->
## License

Distributed under the MIT License. See `LICENSE.txt` for more information.

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- CONTACT -->
## Contact

Jake Neau - jakeneau@proton.me

Project Link: [https://github.com/JakeNeau/Jake-Neau-NixOS-Config](https://github.com/JakeNeau/Jake-Neau-NixOS-Config)

<p align="right">(<a href="#readme-top">back to top</a>)</p>



<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->
[contributors-shield]: https://img.shields.io/github/contributors/JakeNeau/Jake-Neau-NixOS-Config.svg?style=for-the-badge
[contributors-url]: https://github.com/JakeNeau/Jake-Neau-NixOS-Config/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/JakeNeau/Jake-Neau-NixOS-Config.svg?style=for-the-badge
[forks-url]: https://github.com/JakeNeau/Jake-Neau-NixOS-Config/network/members
[stars-shield]: https://img.shields.io/github/stars/JakeNeau/Jake-Neau-NixOS-Config.svg?style=for-the-badge
[stars-url]: https://github.com/JakeNeau/Jake-Neau-NixOS-Config/stargazers
[issues-shield]: https://img.shields.io/github/issues/JakeNeau/Jake-Neau-NixOS-Config.svg?style=for-the-badge
[issues-url]: https://github.com/JakeNeau/Jake-Neau-NixOS-Config/issues
[license-shield]: https://img.shields.io/github/license/JakeNeau/Jake-Neau-NixOS-Config.svg?style=for-the-badge
[license-url]: https://github.com/JakeNeau/Jake-Neau-NixOS-Config/blob/master/LICENSE.txt
[linkedin-shield]: https://img.shields.io/badge/-LinkedIn-black.svg?style=for-the-badge&logo=linkedin&colorB=555
[linkedin-url]: https://linkedin.com/in/jake-neau
[product-screenshot]: images/screenshot.png
<!-- Shields.io badges. You can a comprehensive list with many more badges at: https://github.com/inttter/md-badges -->
[Next.js]: https://img.shields.io/badge/next.js-000000?style=for-the-badge&logo=nextdotjs&logoColor=white
[Next-url]: https://nextjs.org/
[React.js]: https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB
[React-url]: https://reactjs.org/
[Vue.js]: https://img.shields.io/badge/Vue.js-35495E?style=for-the-badge&logo=vuedotjs&logoColor=4FC08D
[Vue-url]: https://vuejs.org/
[Angular.io]: https://img.shields.io/badge/Angular-DD0031?style=for-the-badge&logo=angular&logoColor=white
[Angular-url]: https://angular.io/
[Svelte.dev]: https://img.shields.io/badge/Svelte-4A4A55?style=for-the-badge&logo=svelte&logoColor=FF3E00
[Svelte-url]: https://svelte.dev/
[Laravel.com]: https://img.shields.io/badge/Laravel-FF2D20?style=for-the-badge&logo=laravel&logoColor=white
[Laravel-url]: https://laravel.com
[Bootstrap.com]: https://img.shields.io/badge/Bootstrap-563D7C?style=for-the-badge&logo=bootstrap&logoColor=white
[Bootstrap-url]: https://getbootstrap.com
[JQuery.com]: https://img.shields.io/badge/jQuery-0769AD?style=for-the-badge&logo=jquery&logoColor=white
[JQuery-url]: https://jquery.com
[Nix.com]: https://img.shields.io/badge/Nix-5277C3?logo=nixos&logoColor=white
[Nix-url]: https://nix.dev/reference/nix-manual.html
[NixOS.com]: https://img.shields.io/badge/NixOS-5277C3?logo=nixos&logoColor=white
[NixOS-url]: https://nixos.org/manual/nixos/stable/
