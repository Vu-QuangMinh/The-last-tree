"""Where the exporters / importers put art now that assets/ is split into Global / New / Puppet (see assets/README.md).
Every theme folder has the same shape, so these helpers only need the theme folder."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "assets"))
GLOBAL = os.path.join(ASSETS, "Global")
NEW = os.path.join(ASSETS, "New")
PUPPET = os.path.join(ASSETS, "Puppet")

# the New set's old folder names -> where that kind of art lives now (inside a theme folder)
FOLDER = {"panels": "UI/Panels", "buttons": "UI/Buttons", "essence": "UI/Essence", "intent": "Icon/Intent", "status": "Icon/Effect",
          "icons": "UI/Icons", "cards": "Card", "numbers": "UI/Numbers", "treasure": "Card/Treasure", "map": "Map", "fx": "UI/Fx",
          "title": "UI/Banners", "characters": "UI/Characters", "artifacts": "Icon/Artifact", "bottles": "Icon/Bottle",
          "campfire": "Map/Rooms/Campfire", "room": "Map/Rooms/Apothecary", "misc": "UI/Misc"}


def sub_of(folder, name):
    """Sub-folder (inside a theme folder, '/'-separated) for the art `name` that used to go to the old `folder`."""
    if folder == "backgrounds":
        return "Stage/Act%s/Backdrop" % name[6] if name.startswith("bg_act") else "Map/Rooms/Backgrounds"
    if folder == "leaves":
        return "Stage/Act%s/Fx" % name[6]
    if name.startswith("hp_"):
        return "UI/Hp"
    if name.startswith(("machine_", "tube_", "crank_")) or name in ("box_front", "globe_front", "pipe_front"):
        return "UI/Machine"
    if name == "panel_paper_frame":
        return "UI/Hint"
    if name.startswith("wax_seal"):
        return "Card"
    if name.startswith("banner_"):
        return "UI/Banners"
    return FOLDER[folder]


def art_path(theme_dir, old_folder, name, ext=".png"):
    """Full path of `name` in a theme folder, the folder made if needed. old_folder is the name the folder had in the old assets/ui/new/."""
    d = os.path.join(theme_dir, *sub_of(old_folder, name).split("/"))
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name + ext)


def panel_path(theme_dir, name):
    """A Puppet panel / HP / machine piece: where it goes by its name."""
    return art_path(theme_dir, "panels", name)


def source_dir(theme_dir, *parts):
    """The _Source folder (raw PDFs, PSDs and big pictures that Godot does not import) of a theme folder."""
    d = os.path.join(theme_dir, "_Source", *parts)
    os.makedirs(d, exist_ok=True)
    return d
