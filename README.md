# Sierra reverse engineering

In the late 1980's until the early 1990's, [Sierra On-Line](https://en.wikipedia.org/wiki/Sierra_Entertainment) was a major video game developer well known for their adventure game series, such as King's Quest, Quest for Glory, Leisure Suit Larry, Police Quest and many more. If you are looking to play these old games, I recommend visiting [Good Old Games](https://www.gog.com): it is unlikely you'll find anything of value in this repository unless you are a programmer.

As a kid, I loved these games and soon I started wondering how they worked. It turns out all games use a custom engine, initially [Adventure Game Interpreter](https://en.wikipedia.org/wiki/Adventure_Game_Interpreter) and later _Script Interpreter_ (also known as _Sierra's Creative Interpreter_). I've mainly looked into the latter (SCI) games and this led to some involvement in the FreeSCI project (which has later been incorporated into [ScummVM](https://www.scummvm.org)). The design of such early software fascinates me: I love digging in and learning/discovering things!

Recently, I decided to start to properly clean up, write down and publish the information I've found and am still learning. Feedback (corrections, additional information, heck: anything really) is most welcome, preferably via email to rink@rink.nu.

## Contents

- [Sound drivers](sound-drivers/README.md) - contains reverse engineered, commented sound drivers sources that yield byte-for-byte identical binaries to the original drivers (SCI0/SCI1)
