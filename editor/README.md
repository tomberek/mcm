# Modified GitHub Editor

Instructions for obtaining and setting up a modified Prose.io app with live-editing using pandoc.

1.  ## Prose.io

You have two options, build a brand new updated project with a few modifications, or just take the prebuilt app from the [repo](https://github.com/deptofdefense/mcm/editor).

### Obtain Prose.io and modify
Obtain the Prose.io app from [here](https://github.com/prose/prose). Follow the instructions in it's readme till before `npm i` to build the project. The modifications needed:
    1.  global access to editor,
    2.  disable `marked` processing of markdown, (app/views/file.js#L698,730)
    3.  disable hiding of preview pane, (app/views/file.js#L839) and
    4.  including any JS or CSS into index.html.

### Or, use modified build
There is a modified build at [https://github.com/tomberek/prose](https://github.com/tomberek/prose), master branch at SHA1: `7f8e6d73a69929bdfe5bf74ea7bdcdb166350477`

2.  ## Pandoc-light
Easiest way to build pandoc-light is to use the Nix package manager to install [GHCJS](https://github.com/reflex-frp/reflex-platform). Add pandoc-light to the platform. This [patch can help.](https://github.com/tomberek/pandoc-light/blob/master/0001-pandoc-light-add.patch) Once in a nix-shell with reflex-platform, a simple `cabal install --bindir=.` will place compiled JS into `./pandoc-editor.jsexe`.

3. ## Combine the projects.
The below script shows the procedure up to and including this point.

```
git clone git@github.com:tomberek/prose
cd prose
git checkout 7f8e6d73a69929bdfe5bf74ea7bdcdb166350477
npm i
cd ..
git checkout git@github.com:reflex-frp/reflex-platform
cd reflex-platform
git checkout git@github.com:tomberek/pandoc-light
mv ./pandoc-light/0001-pandoc-light-add.patch .

# May need to revise this as the reflex-platform evolves
git apply --check 0001-pandoc-light-add.patch 
git apply 0001-pandoc-light-add.patch 
./work-on ghcjs ./pandoc-light
cd pandoc-light
cabal install --bindir=.

# If you have Google's Closure Compiler (`nix-env -i closure-compiler` or `brew install cjcs` 
./minify.sh ./pandoc-editor.jsexe/all.js
mv all.min.js ../../prose/dist/all.js

# Finished
cd ../..

# Now you can test this by loading `./prose/index.html` into a browser.
Keep in mind that Prose.io uses a hosted mechanism for GitHub authentication.
```

