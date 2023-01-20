# ModRemapper
Automagically downloads the correct mappings for the specified game version, downloads tiny-remapper and remaps the given jar from intermediary to named.

## Usage
`modRemapper.sh <path to jarfile> <game version>`

Example: `modRemapper.sh input.jar 1.19.3` to remap `input.jar`, which was built for game version `1.19.3`, from intermediary to named mappings.

The mapped output jarfile will be located in the same directory as the input jarfile, with the `-remapped` suffix. Ex. for `input.jar`: `input-remapped.jar`