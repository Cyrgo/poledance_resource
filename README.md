# Poledance Resource (Qbox Fork)

![poledance,png](https://github.com/B0STRA/bostra_poledance/assets/119994243/76e5d08d-5d5d-4903-8bcf-8392f508eebe)

This is a **forked and modified version** of the original `bostra_poledance` resource, adapted for the **Qbox Framework**.

## Original Credits

**Original Author**: B0STRA  
**Original Resource**: [bostra_poledance](https://github.com/B0STRA/bostra_poledance)  
**Support**: [Mustache Scripts - Discord](https://discord.gg/RVx8nVwcEG)  
**Tip the Original Author**: [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A46AZW4)

---

## Fork Modifications

This fork has been **specifically adapted for Qbox Framework** with the following changes:

### ✅ **Framework Compatibility**
- **Qbox Framework** support (qbx_core instead of qb-core)
- **ox_target integration** (changed from qb-target to ox_target)
- Updated framework detection and event handlers
- Compatible with Qbox ecosystem

### ✅ **Configuration Updates**
- Target system changed from `'qb'` to `'ox'` in config
- Added proper qbx_core event handlers
- Fixed resource loading for Qbox framework

---

## Features

- **Target and Zone text UI** supported
- **3 unique pole dances** with synchronized animations
- **6 enticing lap dances** for enhanced roleplay
- **Job locks with target** system
- **Dynamic tool** for creating new poles (`/newpole` admin command)
- **Easy location adding** with coordinate copying
- **ox_target integration** for smooth interactions
- **Keybind support** (X to cancel dance)

## Dependencies

- **ox_lib** - Required for UI and utilities
- **ox_target** - For interaction targeting (Qbox compatible)
- **qbx_core** - Qbox Framework core

## Installation

1. **Download** this resource and place it in your `resources/[standalone]/` directory
2. **Ensure dependencies** are loaded **before** this resource in `server.cfg`:
   ```
   ensure ox_lib
   ensure ox_target
   ensure qbx_core
   ensure poledance_resource
   ```
3. **Restart** the server or resource: `restart poledance_resource`

## Configuration

### Target System
The resource is pre-configured to use **ox_target** for Qbox compatibility. The config automatically uses:
```lua
Target = 'ox'  -- Uses ox_target instead of qb-target
```

### Adding New Pole Locations

#### Method 1: Admin Command
1. Use the `/newpole` admin command in-game
2. Aim where you want the pole and press **E** to confirm
3. Coordinates are **automatically copied to clipboard**
4. Paste into `config/config.lua` under the `Poles` section

#### Method 2: Manual Configuration
Add poles manually to `config/config.lua`:
```lua
Poles = {
    { 
        position = vec4(x, y, z, heading), 
        spawn = true,  -- Set to true to spawn a physical pole
        job = 'jobname' -- Optional: restrict to specific job
    },
}
```

### Current Pole Locations
- **Custom Location**: Configurable via admin command
- **Vanilla Unicorn**: Pre-configured locations with job lock (`job = 'unicorn'`)

## Usage

### For Players
1. **Approach** a pole location
2. **Interact** using ox_target (look at pole and use interaction menu)
3. **Select** from pole dances (1-3) or lap dances (1-6)
4. **Cancel** anytime by pressing **X**

### For Admins
- **`/newpole`** - Create new pole locations dynamically
- Coordinates automatically copied to clipboard for easy config updates

## Advanced Configuration

### Job Restrictions
Restrict poles to specific jobs:
```lua
{ position = vec4(x, y, z, heading), job = 'unicorn', spawn = true }
```

### Housing Integration (Optional)
For [ps-housing](https://github.com/Project-Sloth/ps-housing) compatibility, add to `shared/config.lua`:
```lua        
category = "Misc",
items = {
    { ["object"] = "v_corp_facebeanbag", ["price"] = 100, ["label"] = "Bean Bag 1" },
    { ["object"] = "prop_strip_pole_01", ["price"] = 2500, ["label"] = "Dance Pole" },
}
```

## Preview
- [Streamable Preview](https://streamable.com/fphors)

## Known Issues
- Spawned props may create duplicate target options
- Scene coordinates could be optimized for better positioning

## Differences from Original
This Qbox fork includes:
- ✅ **ox_target** instead of qb-target
- ✅ **qbx_core** event handlers
- ✅ **Qbox framework** compatibility
- ✅ **Updated dependencies** for Qbox ecosystem

---

## License

This fork maintains the original license terms. Please respect both the original author's work and this adaptation.

## Support

**For this Qbox fork**: Create issues in this repository  
**For the original resource**: [Mustache Scripts Discord](https://discord.gg/RVx8nVwcEG)  
**Support the original author**: [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A46AZW4)