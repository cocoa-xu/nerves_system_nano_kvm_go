################################################################################
#
# axera-npu
#
################################################################################

AXERA_NPU_VERSION = 55dd263fe124c71b2018acc784ad03d93c9c3b8c
AXERA_NPU_SITE = $(call github,cocoa-xu,axera_npu,$(AXERA_NPU_VERSION))
AXERA_NPU_LICENSE = GPL-2.0-only (driver), Apache-2.0
AXERA_NPU_LICENSE_FILES = kernel/COPYING LICENSE
AXERA_NPU_MODULE_SUBDIRS = kernel

$(eval $(kernel-module))
$(eval $(generic-package))
