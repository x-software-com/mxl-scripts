# Overview

MXL-Scripts is an open source collection of scripts to test and build MXL Products.

# Setup

[Install just](https://just.systems/man/en/packages.html)

```sh
just setup
```

# Usage

Please follow the [conventional commit](https://www.conventionalcommits.org/en/v1.0.0/#summary) specification when merging from the MXL-Scripts repository or committing to it.

## Integration

To integrate the MXL-Scripts into a repository:

```sh
$ git submodule add https://github.com/x-software-com/mxl-scripts.git scripts
```

Create a `.build-env` file with the following content in the root directory of your repository and change the values according to your product:

```env
export LICENSES_DIR="${PKG_DIR}/usr/share/licenses"
export APP_ID_BASE="com.x-software.mxl"
export PACKAGE="mxl_product"
export APP_NAME="MXL_Product"
export PRODUCT_PRETTY_NAME="MXL Product"
export APP_ID="${APP_ID_BASE}.product"
export ADDITIONAL_SANCUS_ARGS="--additional-third-party-licenses ${LICENSES_DIR}/${APP_ID_BASE}.product_tool_third_party_licenses.json"
export ADDITIONAL_LINUXDEPLOY_ARGS=""
```

## Update

To update the MXL-Scripts in a repository:

```sh
$ cd scripts
$ git checkout main
$ git pull
```

Commit the updated submodule.

# License

The code in this repository is licensed under either of [APACHE-2.0 License](LICENSE-APACHE) or [MIT License](LICENSE-MIT) at your option.
