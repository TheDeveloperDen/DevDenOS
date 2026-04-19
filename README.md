# DevDenOS
Operating System in the Key of Developer Den (Shout out to Brister for allowing
this)

There is pretty much one rule (outside of rules implied by common sense), which
is that core OS functionality must be written in Assembly. Userspace programs,
like a clock, a game, or whatever can be written in any language (that you can
manage to get working), but the core parts of the OS must be assembly.

## Concept
The idea is a Discord client OS. It is at it's core, a Discord client, and
should allow you to connect your account to it and chat on the Developer Den
discord only. However, you should be able to pull up other functionality like a
text editor, compiler, clock, or even perhaps games. Discored will never close,
though.

Windows should dynamically tile around Discord.

## Tools
NASM (Intel Syntax)
x86-64 QEMU (Base firmware, base CPU settings)
