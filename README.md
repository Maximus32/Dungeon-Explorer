%==========================%
% ~ DUNGEON EXPLORER 1.0 ~ %
%==========================%

A hobby project I'm working on, exploring algorithms involved in creating and solving (traversing) "dungeons": mazes (or mathematical graphs) with locked doors and switches. Inspired by older Zelda games when solving dungeons was more of a logic and memory puzzle than a test of dexterity or skill.

Basically, a Dungeon is a mathematical graph with rooms representing nodes and doors representing paths between them. Locked doors are inaccessable paths, which can be opened by pressing switches or collecting keys stored in rooms. This command line program explores the creation, solving, and displaying of dungeons

Dungeon creation, called Assembly, can be User-driven or randomly generated. It involves graphically placing rooms, doors, and events (switches and keys) to build a (hopefully solveable) dungeon

Dungeon solving, called Crawling, involves generating paths and sub-paths that, when followed, can lead a human from one point in the dungeon to another. Most important is the idea of locked doors and switches, which must be changed at specific points along the path to ensure a solution is found

Dungeon visualization, called Printing, is completely text based and transfers objects like rooms and doors to ASCII representations into a text file

Currently, this is just a personal project and is very much incomplete (and error ridden!)

Ah, and it's built using Ruby :)
