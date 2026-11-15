################################################################################
#
# axera-npu
#
################################################################################

AXERA_NPU_VERSION = da8e371b5c3bb31de3a2cb47da185513760f624c
AXERA_NPU_SITE = $(call github,cocoa-xu,axera_npu,$(AXERA_NPU_VERSION))
AXERA_NPU_LICENSE = GPL-2.0-only (driver), Apache-2.0
AXERA_NPU_LICENSE_FILES = kernel/COPYING LICENSE
AXERA_NPU_MODULE_SUBDIRS = kernel

$(eval $(kernel-module))
$(eval $(generic-package))
