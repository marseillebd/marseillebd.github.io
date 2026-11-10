# Self-Documenting Code

I was recently trying to pick apart the XCompose functionality that's built-in to X11,
  since I was having some issues with my configs and I was running XIM, which I _think_ is uilt into X11?
I haven't figured it out yet (at time of writing), and am considering using Ghidra to detangle it.

Can you imagine that?
I have the C source code, but I'd rather decompile it??
What went wrong with this project?

Consider where you might look for code related to XCompose.
The `libX11/modules/im/` folder makes sense, but from there it goes downhill:
  `ximcp/imLcIm.c` contains code that looks like it is responsible for loading the XCompose configs.
Is `ximcp` a copy of a separate xim repository from before the time of git submodules?
I take it that `im` means "input method", so why does it have `Im` a second time?
I am completely in the dark about `Lc`; I'm pretty certain it's not "letter of credit", or even "Leet Code", which is what pops up when I search the acronym.

Well, probably there's some verbose documentation from which I could, in principle, infer the meanings of these abbreviations after thorough reading.
Ultimately, what `Lc` stands for doesn't matter to me; I just want to understand why my XCompose is broken, so it's not worth all the reading.
I'll just carry on following the control flow with little idea of the intention behind the written code.

Now, self-documenting code has gotten something of a bad rap: there's no such thing, you see.
Well, I'm not convinced that "self-documenting code" is actually what it says on the tin.

Sometimes, self-documenting code is spelling `creat` with an `e`.
Sometimes, it's having names for things that are more descriptive than `imLcIm`.
Sometimes, it's not writing the struct member `Bool (*im_open)(Xim im);` across three lines.

Take the time to ask yourself:
  what if someone finds this function using grep without first reading every word of my 300-page so-called manual?
