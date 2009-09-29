# -----------------------------------------------------------------------------
#
# (c) 2009 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Modifying
#
# -----------------------------------------------------------------------------

# ToDo List.
#
#   * finish installation
#     * Windows: should we have ghc-pkg-<version>?
#     * should we be stripping things?
#     * install libgmp.a, gmp.h
#   * need to fix Cabal for new Windows layout, see
#     Distribution/Simple/GHC.configureToolchain.
#   * remove old Makefiles, add new stubs for building in subdirs
#     * docs/Makefile
#     * docs/docbook-cheat-sheet/Makefile
#     * docs/ext-core/Makefile
#     * docs/man/Makefile
#     * docs/storage-mgmt/Makefile
#     * docs/vh/Makefile
#     * rts/dotnet/Makefile
#     * utils/Makefile
#   * optionally install stage3?
#   * add Makefiles for the rest of the utils/ programs that aren't built
#     by default (need to exclude them from 'make all' too)
#
# Tickets we can now close, or fix and close:
#
#   * 1693 make distclean

# Possible cleanups:
#
#   * per-source-file dependencies instead of one .depend file?
#   * eliminate undefined variables, and use --warn-undefined-variables?
#   * perhaps we should make all the output dirs in the .depend rule, to
#     avoid all these mkdirhier calls?
#   * put outputs from different ways in different subdirs of distdir/build,
#     then we don't have to use -osuf/-hisuf.  We would have to install
#     them in different places too, so we'd need ghc-pkg support for packages
#     of different ways.
#   * make PACKAGES generated by configure or sh boot?
#   * we should use a directory of package.conf files rather than a single
#     file for the inplace package database, so that we can express
#     dependencies more accurately.  Otherwise it's possible to get into
#     a state where the package database is out of date, and the build
#     system doesn't know.

# Approximate build order.
#
# The actual build order is defined by dependencies, and the phase
# ordering used to ensure correct ordering of makefile-generation; see
#    http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture/Idiom/PhaseOrdering
#
#     * With bootstrapping compiler:
#           o Build utils/ghc-cabal
#           o Build utils/ghc-pkg
#           o Build utils/hsc2hs
#     * For each package:
#	    o configure, generate package-data.mk and inplace-pkg-info
#           o register each package into inplace/lib/package.conf
#     * build libffi
#     * With bootstrapping compiler:
#	    o Build libraries/{filepath,hpc,extensible-exceptions,Cabal}
#           o Build compiler (stage 1)
#     * With stage 1:
#           o Build libraries/*
#	    o Build rts
#           o Build utils/* (except haddock)
#           o Build compiler (stage 2)
#     * With stage 2:
#           o Build utils/haddock
#           o Build compiler (stage 3) (optional)
#     * With haddock:
#           o libraries/*
#           o compiler

.PHONY: default all haddock

default : all

# Catch make if it runs away into an infinite loop
ifeq      "$(MAKE_RESTARTS)" ""
else ifeq "$(MAKE_RESTARTS)" "1"
else ifeq "$(MAKE_RESTARTS)" "2"
else
$(error Make has restarted itself $(MAKE_RESTARTS) times; is there a makefile bug?)
endif

# Just bring makefiles up to date:
.PHONY: just-makefiles
just-makefiles:
	@:

# -----------------------------------------------------------------------------
# Misc GNU make utils

nothing=
space=$(nothing) $(nothing)
comma=,

# Cancel all suffix rules.  Ideally we'd like to have 'make -r' turned on
# by default, because that disables all the implicit rules, but there doesn't
# seem to be a good way to do that.  This turns off all the old-style suffix
# rules, which does half the job and speeds up make quite a bit:
.SUFFIXES:

# -----------------------------------------------------------------------------
# 			Makefile debugging
# to see the effective value used for a Makefile variable, do
#  make show VALUE=MY_VALUE
#

show:
	@echo '$(VALUE)="$($(VALUE))"'

# -----------------------------------------------------------------------------
# Include subsidiary build-system bits

include mk/tree.mk

ifeq "$(findstring clean,$(MAKECMDGOALS))" ""
include mk/config.mk
ifeq "$(ProjectVersion)" ""
$(error Please run ./configure first)
endif
endif

include mk/ways.mk

# (Optional) build-specific configuration
include mk/custom-settings.mk

ifeq "$(findstring clean,$(MAKECMDGOALS))" ""
ifeq "$(GhcLibWays)" ""
$(error $$(GhcLibWays) is empty, it must contain at least one way)
endif
endif

# -----------------------------------------------------------------------------
# Macros for standard targets

include rules/all-target.mk
include rules/clean-target.mk

# -----------------------------------------------------------------------------
# The inplace tree

$(eval $(call clean-target,inplace,,inplace))

# -----------------------------------------------------------------------------
# Whether to build dependencies or not

# When we're just doing 'make clean' or 'make show', then we don't need
# to build dependencies.

ifneq "$(findstring clean,$(MAKECMDGOALS))" ""
NO_INCLUDE_DEPS = YES
NO_INCLUDE_PKGDATA = YES
endif
ifneq "$(findstring bootstrapping-files,$(MAKECMDGOALS))" ""
NO_INCLUDE_DEPS = YES
NO_INCLUDE_PKGDATA = YES
endif
ifeq "$(findstring show,$(MAKECMDGOALS))" "show"
NO_INCLUDE_DEPS = YES
# We want package-data.mk for show
endif

# We don't haddock the bootstrapping libraries
libraries/hpc_dist-boot_DO_HADDOCK = NO
libraries/Cabal_dist-boot_DO_HADDOCK = NO
libraries/extensible-exceptions_dist-boot_DO_HADDOCK = NO
libraries/filepath_dist-boot_DO_HADDOCK = NO
libraries/binary_dist-boot_DO_HADDOCK = NO
libraries/bin-package-db_dist-boot_DO_HADDOCK = NO

# -----------------------------------------------------------------------------
# Ways

include rules/way-prelims.mk

$(foreach way,$(ALL_WAYS),\
  $(eval $(call way-prelims,$(way))))

# -----------------------------------------------------------------------------
# Compilation Flags

include rules/distdir-way-opts.mk

# -----------------------------------------------------------------------------
# Finding source files and object files

include rules/hs-sources.mk
include rules/c-sources.mk
include rules/includes-sources.mk
include rules/hs-objs.mk
include rules/c-objs.mk
include rules/cmm-objs.mk

# -----------------------------------------------------------------------------
# Suffix rules

# Suffix rules cause "make clean" to fail on Windows (trac #3233)
# so we don't make any when cleaning.
ifneq "$(CLEANING)" "YES"

include rules/hs-suffix-rules-srcdir.mk
include rules/hs-suffix-rules.mk

# -----------------------------------------------------------------------------
# Suffix rules for .hi files

include rules/hi-rule.mk

$(foreach way,$(ALL_WAYS),\
  $(eval $(call hi-rule,$(way))))

#-----------------------------------------------------------------------------
# C-related suffix rules

include rules/c-suffix-rules.mk

#-----------------------------------------------------------------------------
# CMM-related suffix rules

include rules/cmm-suffix-rules.mk

endif

# -----------------------------------------------------------------------------
# Building package-data.mk files from .cabal files

include rules/package-config.mk

# -----------------------------------------------------------------------------
# Building dependencies

include rules/build-dependencies.mk

# -----------------------------------------------------------------------------
# Build package-data.mk files

include rules/build-package-data.mk

# -----------------------------------------------------------------------------
# Build and install a program

include rules/build-prog.mk
include rules/shell-wrapper.mk

# -----------------------------------------------------------------------------
# Build a perl script

include rules/build-perl.mk

# -----------------------------------------------------------------------------
# Build a package

include rules/build-package.mk
include rules/build-package-way.mk
include rules/haddock.mk

# -----------------------------------------------------------------------------
# Registering hand-written package descriptions (used in libffi and rts)

include rules/manual-package-config.mk

# -----------------------------------------------------------------------------
# Docs

include rules/docbook.mk

# -----------------------------------------------------------------------------
# Making bindists

include rules/bindist.mk

# -----------------------------------------------------------------------------
# Building libraries

define addPackage # args: $1 = package, $2 = condition
    ifneq "$2" ""
        ifeq "$$(CLEANING)" "YES"
            PACKAGES += $1
        else
            ifeq $2
                PACKAGES += $1
            endif
        endif
    else
        PACKAGES += $1
    endif
endef

$(eval $(call addPackage,ghc-prim))
ifeq "$(CLEANING)" "YES"
$(eval $(call addPackage,integer-gmp))
$(eval $(call addPackage,integer-simple))
else
$(eval $(call addPackage,$(INTEGER_LIBRARY)))
endif
$(eval $(call addPackage,base))
$(eval $(call addPackage,filepath))
$(eval $(call addPackage,array))
$(eval $(call addPackage,bytestring))
$(eval $(call addPackage,containers))

$(eval $(call addPackage,Win32,($$(Windows),YES)))
$(eval $(call addPackage,unix,($$(Windows),NO)))

$(eval $(call addPackage,old-locale))
$(eval $(call addPackage,old-time))
$(eval $(call addPackage,time))
$(eval $(call addPackage,directory))
$(eval $(call addPackage,process))
$(eval $(call addPackage,random))
$(eval $(call addPackage,extensible-exceptions))
$(eval $(call addPackage,haskell98))
$(eval $(call addPackage,hpc))
$(eval $(call addPackage,pretty))
$(eval $(call addPackage,template-haskell))
$(eval $(call addPackage,Cabal))
$(eval $(call addPackage,binary))
$(eval $(call addPackage,bin-package-db))
$(eval $(call addPackage,mtl))
$(eval $(call addPackage,utf8-string))

$(eval $(call addPackage,terminfo,($$(Windows),NO)))

$(eval $(call addPackage,haskeline))

ifneq "$(BootingFromHc)" "YES"
PACKAGES_STAGE2 += \
	dph/dph-base \
	dph/dph-prim-interface \
	dph/dph-prim-seq \
	dph/dph-prim-par \
	dph/dph-seq \
	dph/dph-par
endif

# We assume that the stage0 compiler has a suitable bytestring package,
# so we don't have to include it below.
BOOT_PKGS = Cabal hpc extensible-exceptions binary bin-package-db

# The actual .a and .so/.dll files: needed for dependencies.
ALL_STAGE1_LIBS  = $(foreach lib,$(PACKAGES),$(libraries/$(lib)_dist-install_v_LIB))
ifeq "$(BuildSharedLibs)" "YES"
ALL_STAGE1_LIBS += $(foreach lib,$(PACKAGES),$(libraries/$(lib)_dist-install_dyn_LIB))
endif
BOOT_LIBS = $(foreach lib,$(BOOT_PKGS),$(libraries/$(lib)_dist-boot_v_LIB))

OTHER_LIBS = libffi/libHSffi$(v_libsuf) libffi/HSffi.o
ifeq "$(BuildSharedLibs)" "YES"
OTHER_LIBS  += libffi/libHSffi$(dyn_libsuf)
endif

# We cannot run ghc-cabal to configure a package until we have
# configured and registered all of its dependencies.  So the following
# hack forces all the configure steps to happen in exactly the order
# given in the PACKAGES variable above.  Ideally we should use the
# correct dependencies here to allow more parallelism, but we don't
# know the dependencies until we've generated the pacakge-data.mk
# files.
define fixed_pkg_dep
libraries/$1/$2/package-data.mk : $$(GHC_PKG_INPLACE) $$(if $$(fixed_pkg_prev),libraries/$$(fixed_pkg_prev)/$2/package-data.mk)
fixed_pkg_prev:=$1
endef

ifneq "$(BINDIST)" "YES"
fixed_pkg_prev=
$(foreach pkg,$(PACKAGES) $(PACKAGES_STAGE2),$(eval $(call fixed_pkg_dep,$(pkg),dist-install)))

# We assume that the stage2 compiler depends on all the libraries, so
# they all get added to the package database before we try to configure
# it
compiler/stage2/package-data.mk: $(foreach pkg,$(PACKAGES) $(PACKAGES_STAGE2),libraries/$(pkg)/dist-install/package-data.mk)
ghc/stage1/package-data.mk: compiler/stage1/package-data.mk
ghc/stage2/package-data.mk: compiler/stage2/package-data.mk
# haddock depends on ghc and some libraries, but depending on GHC's
# package-data.mk is sufficient, as that in turn depends on all the
# libraries
utils/haddock/dist/package-data.mk: compiler/stage2/package-data.mk

utils/hsc2hs/dist-install/package-data.mk: compiler/stage2/package-data.mk

# add the final two package.conf dependencies: ghc-prim depends on RTS,
# and RTS depends on libffi.
libraries/ghc-prim/dist-install/package-data.mk : rts/package.conf.inplace
rts/package.conf.inplace : libffi/package.conf.inplace
endif

# -----------------------------------------------------------------------------
# Special magic for the ghc-prim package

# We want the ghc-prim package to include the GHC.Prim module when it
# is registered, but not when it is built, because GHC.Prim is not a
# real source module, it is built-in to GHC.  The old build system did
# this using Setup.hs, but we can't do that here, so we have a flag to
# enable GHC.Prim in the .cabal file (so that the ghc-prim package
# remains compatible with the old build system for the time being).
# GHC.Prim module in the ghc-prim package with a flag:
#
libraries/ghc-prim_CONFIGURE_OPTS += --flag=include-ghc-prim

# And then we strip it out again before building the package:
define libraries/ghc-prim_PACKAGE_MAGIC
libraries/ghc-prim_dist-install_MODULES := $$(filter-out GHC.Prim,$$(libraries/ghc-prim_dist-install_MODULES))
endef

PRIMOPS_TXT = $(GHC_COMPILER_DIR)/prelude/primops.txt

libraries/ghc-prim/dist-install/build/GHC/PrimopWrappers.hs : $(GENPRIMOP_INPLACE) $(PRIMOPS_TXT)
	"$(MKDIRHIER)" $(dir $@)
	"$(GENPRIMOP_INPLACE)" --make-haskell-wrappers <$(PRIMOPS_TXT) >$@

libraries/ghc-prim/GHC/Prim.hs : $(GENPRIMOP_INPLACE) $(PRIMOPS_TXT)
	"$(GENPRIMOP_INPLACE)" --make-haskell-source <$(PRIMOPS_TXT) >$@


# -----------------------------------------------------------------------------
# Include build instructions from all subdirs

# For the rationale behind the build phases, see
#   http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture/Idiom/PhaseOrdering

# Setting foo_dist_DISABLE=YES means "in directory foo, for build
# "dist", just read the package-data.mk file, do not build anything".

# We carefully engineer things so that we can build the
# package-data.mk files early on: they depend only on a few tools also
# built early.  Having got the package-data.mk files built, we can
# restart make with up-to-date information about all the packages
# (this is phase 0).  The remaining problem is the .depend files:
#
#   - .depend files in libraries need the stage 1 compiler to build
#   - ghc/stage1/.depend needs compiler/stage1 built
#   - compiler/stage1/.depend needs the bootstrap libs built
#
# GHC 6.11+ can build a .depend file without having built the
# dependencies of the package, but we can't rely on the bootstrapping
# compiler being able to do this, which is why we have to separate the
# three phases above.

# So this is the final ordering:

# Phase 0 : all package-data.mk files
#           (requires ghc-cabal, ghc-pkg, mkdirhier, dummy-ghc etc.)
# Phase 1 : .depend files for bootstrap libs
#           (requires hsc2hs)
# Phase 2 : compiler/stage1/.depend
#           (requires bootstrap libs and genprimopcode)
# Phase 3 : ghc/stage1/.depend
#           (requires compiler/stage1)
#
# The rest : libraries/*/dist-install, compiler/stage2, ghc/stage2

BUILD_DIRS =

ifneq "$(BINDIST)" "YES"
BUILD_DIRS += \
   $(GHC_MKDEPENDC_DIR) \
   $(GHC_MKDIRHIER_DIR)
endif

BUILD_DIRS += \
   docs/users_guide \
   libraries/Cabal/doc \
   $(GHC_UNLIT_DIR) \
   $(GHC_HP2PS_DIR)

ifneq "$(GhcUnregisterised)" "YES"
BUILD_DIRS += \
   $(GHC_MANGLER_DIR) \
   $(GHC_SPLIT_DIR)
endif

ifneq "$(BINDIST)" "YES"
BUILD_DIRS += \
   $(GHC_GENPRIMOP_DIR)
endif

BUILD_DIRS += \
   driver \
   driver/ghci \
   driver/ghc \
   libffi \
   includes \
   rts

ifneq "$(BINDIST)" "YES"
BUILD_DIRS += \
   $(GHC_CABAL_DIR) \
   $(GHC_GENAPPLY_DIR)
endif

ifneq "$(HADDOCK_DOCS)" "NO"
BUILD_DIRS += \
   utils/haddock \
   utils/haddock/doc
endif

ifneq "$(CLEANING)" "YES"
BUILD_DIRS += \
   $(patsubst %, libraries/%, $(PACKAGES) $(PACKAGES_STAGE2))
ifneq "$(BootingFromHc)" "YES"
BUILD_DIRS += \
   libraries/dph
endif
endif

ifeq "$(INTEGER_LIBRARY)" "integer-gmp"
BUILD_DIRS += libraries/integer-gmp/gmp
endif

BUILD_DIRS += \
   compiler \
   $(GHC_HSC2HS_DIR) \
   $(GHC_PKG_DIR) \
   utils/hpc \
   utils/runghc \
   ghc
ifeq "$(Windows)" "YES"
BUILD_DIRS += \
   $(GHC_TOUCHY_DIR)
endif

# XXX libraries/% must come before any programs built with stage1, see
# Note [lib-depends].

ifeq "$(phase)" "0"
$(foreach lib,$(BOOT_PKGS),$(eval \
  libraries/$(lib)_dist-boot_DISABLE = YES))
endif

ifneq "$(findstring $(phase),0 1)" ""
# We can build deps for compiler/stage1 in phase 2
compiler_stage1_DISABLE = YES
endif

ifneq "$(findstring $(phase),0 1 2)" ""
ghc_stage1_DISABLE = YES
endif

ifneq "$(CLEANING)" "YES"
ifeq "$(INTEGER_LIBRARY)" "integer-gmp"
libraries/base_dist-install_CONFIGURE_OPTS += --flags=-integer-simple
else
    ifeq "$(INTEGER_LIBRARY)" "integer-simple"
	libraries/base_dist-install_CONFIGURE_OPTS += --flags=integer-simple
    else
$(error Unknown integer library: $(INTEGER_LIBRARY))
    endif
endif
endif

ifneq "$(findstring $(phase),0 1 2 3)" ""
# In phases 0-3, we disable stage2-3, the full libraries and haddock
utils/haddock_dist_DISABLE = YES
utils/runghc_dist_DISABLE = YES
utils/hpc_dist_DISABLE = YES
utils/hsc2hs_dist-install_DISABLE = YES
utils/ghc-pkg_dist-install_DISABLE = YES
compiler_stage2_DISABLE = YES
compiler_stage3_DISABLE = YES
ghc_stage2_DISABLE = YES
ghc_stage3_DISABLE = YES
$(foreach lib,$(PACKAGES) $(PACKAGES_STAGE2),$(eval \
  libraries/$(lib)_dist-install_DISABLE = YES))
endif

# These packages don't pass the Cabal checks because hs-source-dirs
# points outside the source directory. This isn't a real problem in
# these cases, so we just skip checking them.
CHECKED_libraries/dph/dph-seq = YES
CHECKED_libraries/dph/dph-par = YES
# In compiler's case, include-dirs points outside of the source tree
CHECKED_compiler = YES

include $(patsubst %, %/ghc.mk, $(BUILD_DIRS))

# We need -fno-warn-deprecated-flags to avoid failure with -Werror
GhcLibHcOpts += -fno-warn-deprecated-flags
ifeq "$(ghc_ge_609)" "YES"
GhcBootLibHcOpts += -fno-warn-deprecated-flags
endif

# Add $(GhcLibHcOpts) to all library builds
$(foreach pkg,$(PACKAGES) $(PACKAGES_STAGE2),$(eval libraries/$(pkg)_dist-install_HC_OPTS += $$(GhcLibHcOpts)))

# XXX Hack; remove this
$(foreach pkg,$(PACKAGES_STAGE2),$(eval libraries/$(pkg)_dist-install_HC_OPTS += -Wwarn))

# A useful pseudo-target
.PHONY: stage1_libs
stage1_libs : $(ALL_STAGE1_LIBS)

ifeq "$(HADDOCK_DOCS)" "YES"
libraries/index.html: $(ALL_HADDOCK_FILES)
	cd libraries && sh gen_contents_index --inplace
$(eval $(call all-target,library_doc_index,libraries/index.html))
INSTALL_LIBRARY_DOCS += libraries/*.html libraries/*.gif libraries/*.css libraries/*.js
CLEAN_FILES += libraries/doc-index* libraries/haddock*.css \
	       libraries/haddock*.js libraries/index*.html libraries/*.gif
endif

ifeq "$(CHECK_PACKAGES)" "YES"
all: check_packages
endif

# -----------------------------------------------------------------------------
# Bootstrapping libraries

# We need to build a few libraries with the installed GHC, since GHC itself
# and some of the tools depend on them:

ifneq "$(BINDIST)" "YES"

ifneq "$(BOOTSTRAPPING_CONF)" ""
ifeq "$(wildcard $(BOOTSTRAPPING_CONF))" ""
$(shell echo "[]" >$(BOOTSTRAPPING_CONF))
endif
endif

$(eval $(call clean-target,$(BOOTSTRAPPING_CONF),,$(BOOTSTRAPPING_CONF)))

# These three libraries do not depend on each other, so we can build
# them straight off:

$(eval $(call build-package,libraries/hpc,dist-boot,0))
$(eval $(call build-package,libraries/extensible-exceptions,dist-boot,0))
$(eval $(call build-package,libraries/Cabal,dist-boot,0))
$(eval $(call build-package,libraries/binary,dist-boot,0))
$(eval $(call build-package,libraries/bin-package-db,dist-boot,0))

# register the boot packages in strict sequence, because running
# multiple ghc-pkgs in parallel doesn't work (registrations may get
# lost).
fixed_pkg_prev=
$(foreach pkg,$(BOOT_PKGS),$(eval $(call fixed_pkg_dep,$(pkg),dist-boot)))

compiler/stage1/package-data.mk : \
    libraries/Cabal/dist-boot/package-data.mk \
    libraries/hpc/dist-boot/package-data.mk \
    libraries/extensible-exceptions/dist-boot/package-data.mk \
    libraries/bin-package-db/dist-boot/package-data.mk

# These are necessary because the bootstrapping compiler may not know
# about cross-package dependencies:
$(compiler_stage1_depfile) : $(BOOT_LIBS)
$(ghc_stage1_depfile) : $(compiler_stage1_v_LIB)

# A few careful dependencies between bootstrapping packages.  When we
# can rely on the stage 0 compiler being able to generate
# cross-package dependencies with -M (fixed in GHC 6.12.1) we can drop
# these, and also some of the phases.
#
# If you miss any out here, then 'make -j8' will probably tell you.
#
libraries/bin-package-db/dist-boot/build/Distribution/InstalledPackageInfo/Binary.$(v_osuf) : libraries/binary/dist-boot/build/Data/Binary.$(v_hisuf) libraries/Cabal/dist-boot/build/Distribution/InstalledPackageInfo.$(v_hisuf)

$(foreach pkg,$(BOOT_PKGS),$(eval libraries/$(pkg)_dist-boot_HC_OPTS += $$(GhcBootLibHcOpts)))

endif

# -----------------------------------------------------------------------------
# Creating a local mingw copy on Windows

ifeq "$(Windows)" "YES"

# directories don't work well as dependencies, hence a stamp file
$(INPLACE)/stamp-mingw : $(MKDIRHIER)
	$(MKDIRHIER) $(INPLACE_MINGW)/bin
	GCC=`type -p $(WhatGccIsCalled)`; \
	GccDir=`dirname $$GCC`; \
	"$(CP)" -p $$GccDir/{gcc.exe,ar.exe,as.exe,dlltool.exe,dllwrap.exe,windres.exe} $(INPLACE_MINGW)/bin; \
	"$(CP)" -Rp $$GccDir/../include $(INPLACE_MINGW); \
	"$(CP)" -Rp $$GccDir/../lib     $(INPLACE_MINGW); \
	"$(CP)" -Rp $$GccDir/../libexec $(INPLACE_MINGW); \
	"$(CP)" -Rp $$GccDir/../mingw32 $(INPLACE_MINGW)
	touch $(INPLACE)/stamp-mingw

install : install_mingw
.PHONY: install_mingw
install_mingw : $(INPLACE_MINGW)
	"$(CP)" -Rp $(INPLACE_MINGW) $(prefix)

$(INPLACE_LIB)/perl.exe $(INPLACE_LIB)/perl56.dll :
	"$(CP)" $(GhcDir)../{perl.exe,perl56.dll} $(INPLACE_LIB)

endif # Windows

libraries/ghc-prim/dist-install/doc/html/ghc-prim/ghc-prim.haddock: \
    libraries/ghc-prim/dist-install/build/autogen/GHC/Prim.hs \
    libraries/ghc-prim/dist-install/build/autogen/GHC/PrimopWrappers.hs

libraries/ghc-prim/dist-install/build/autogen/GHC/Prim.hs: \
                            $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE) $(MKDIRHIER)
	"$(MKDIRHIER)" $(dir $@)
	"$(GENPRIMOP_INPLACE)" --make-haskell-source < $< > $@

libraries/ghc-prim/dist-install/build/autogen/GHC/PrimopWrappers.hs: \
                            $(PRIMOPS_TXT) $(GENPRIMOP_INPLACE) $(MKDIRHIER)
	"$(MKDIRHIER)" $(dir $@)
	"$(GENPRIMOP_INPLACE)" --make-haskell-wrappers < $< > $@

# -----------------------------------------------------------------------------
# Installation

install: install_packages install_libs install_libexecs install_headers \
         install_libexec_scripts install_bins install_docs \
		 install_topdirs install_topdir_scripts

install_bins: $(INSTALL_BINS)
	$(INSTALL_DIR) $(DESTDIR)$(bindir)
	for i in $(INSTALL_BINS); do \
		$(INSTALL_PROGRAM) $(INSTALL_BIN_OPTS) $$i $(DESTDIR)$(bindir) ;  \
                if test "$(darwin_TARGET_OS)" = "1"; then \
                   sh mk/fix_install_names.sh $(ghclibdir) $(DESTDIR)$(bindir)/$$i ; \
                fi ; \
	done

install_libs: $(INSTALL_LIBS)
	$(INSTALL_DIR) $(DESTDIR)$(ghclibdir)
	for i in $(INSTALL_LIBS); do \
		case $$i in \
		  *.a) \
		    $(INSTALL_DATA) $(INSTALL_OPTS) $$i $(DESTDIR)$(ghclibdir); \
		    $(RANLIB) $(DESTDIR)$(ghclibdir)/`basename $$i` ;; \
		  *.dll) \
		    $(INSTALL_DATA) -s $(INSTALL_OPTS) $$i $(DESTDIR)$(ghclibdir) ;; \
		  *.so) \
		    $(INSTALL_SHLIB) $(INSTALL_OPTS) $$i $(DESTDIR)$(ghclibdir) ;; \
		  *.dylib) \
		    $(INSTALL_SHLIB) $(INSTALL_OPTS) $$i $(DESTDIR)$(ghclibdir); \
		    install_name_tool -id $(DESTDIR)$(ghclibdir)/`basename $$i` $(DESTDIR)$(ghclibdir)/`basename $$i` ;; \
		  *) \
		    $(INSTALL_DATA) $(INSTALL_OPTS) $$i $(DESTDIR)$(ghclibdir); \
		esac; \
	done

install_libexec_scripts: $(INSTALL_LIBEXEC_SCRIPTS)
	$(INSTALL_DIR) $(DESTDIR)$(ghclibexecdir)
	for i in $(INSTALL_LIBEXEC_SCRIPTS); do \
		$(INSTALL_SCRIPT) $(INSTALL_OPTS) $$i $(DESTDIR)$(ghclibexecdir); \
	done

install_libexecs:  $(INSTALL_LIBEXECS)
	$(INSTALL_DIR) $(DESTDIR)$(ghclibexecdir)
	for i in $(INSTALL_LIBEXECS); do \
		$(INSTALL_PROGRAM) $(INSTALL_BIN_OPTS) $$i $(DESTDIR)$(ghclibexecdir); \
	done

install_topdir_scripts: $(INSTALL_TOPDIR_SCRIPTS)
	$(INSTALL_DIR) $(DESTDIR)$(topdir)
	for i in $(INSTALL_TOPDIR_SCRIPTS); do \
		$(INSTALL_SCRIPT) $(INSTALL_OPTS) $$i $(DESTDIR)$(topdir); \
	done

install_topdirs: $(INSTALL_TOPDIRS)
	$(INSTALL_DIR) $(DESTDIR)$(topdir)
	for i in $(INSTALL_TOPDIRS); do \
		$(INSTALL_PROGRAM) $(INSTALL_BIN_OPTS) $$i $(DESTDIR)$(topdir); \
	done

install_headers: $(INSTALL_HEADERS)
	$(INSTALL_DIR) $(DESTDIR)$(ghcheaderdir)
	for i in $(INSTALL_HEADERS); do \
		$(INSTALL_HEADER) $(INSTALL_OPTS) $$i $(DESTDIR)$(ghcheaderdir); \
	done

install_docs: $(INSTALL_HEADERS)
	$(INSTALL_DIR) $(DESTDIR)$(docdir)
	for i in $(INSTALL_DOCS); do \
		$(INSTALL_DOC) $(INSTALL_OPTS) $$i $(DESTDIR)$(docdir); \
	done
	$(INSTALL_DIR) $(INSTALL_OPTS) $(DESTDIR)$(docdir)/html; \
	$(INSTALL_DOC) $(INSTALL_OPTS) docs/index.html $(DESTDIR)$(docdir)/html; \
	for i in $(INSTALL_LIBRARY_DOCS); do \
		$(INSTALL_DOC) $(INSTALL_OPTS) $$i $(DESTDIR)$(docdir)/html/libraries/; \
	done
	for i in $(INSTALL_HTML_DOC_DIRS); do \
		$(INSTALL_DIR) $(INSTALL_OPTS) $(DESTDIR)$(docdir)/html/`basename $$i`; \
		$(INSTALL_DOC) $(INSTALL_OPTS) $$i/* $(DESTDIR)$(docdir)/html/`basename $$i`; \
	done

INSTALLED_PACKAGE_CONF=$(DESTDIR)$(topdir)/package.conf.d

# Install packages in the right order, so that ghc-pkg doesn't complain.
# Also, install ghc-pkg first.
ifeq "$(Windows)" "NO"
INSTALLED_GHC_REAL=$(DESTDIR)$(ghclibexecdir)/ghc-stage2
INSTALLED_GHC_PKG_REAL=$(DESTDIR)$(ghclibexecdir)/ghc-pkg
else
INSTALLED_GHC_REAL=$(DESTDIR)$(bindir)/ghc.exe
INSTALLED_GHC_PKG_REAL=$(DESTDIR)$(bindir)/ghc-pkg.exe
endif

INSTALLED_PACKAGES = $(filter-out haskeline mtl terminfo,$(PACKAGES))
HIDDEN_PACKAGES = ghc-binary

install_packages: install_libexecs
install_packages: libffi/package.conf.install rts/package.conf.install
	$(INSTALL_DIR) $(DESTDIR)$(topdir)
	"$(RM)" -r $(RM_OPTS) $(INSTALLED_PACKAGE_CONF)
	$(INSTALL_DIR) $(INSTALLED_PACKAGE_CONF)
	"$(INSTALLED_GHC_PKG_REAL)" --force --global-conf $(INSTALLED_PACKAGE_CONF) update libffi/package.conf.install
	"$(INSTALLED_GHC_PKG_REAL)" --force --global-conf $(INSTALLED_PACKAGE_CONF) update rts/package.conf.install
	$(foreach p, $(INSTALLED_PACKAGES) $(PACKAGES_STAGE2),\
	    "$(GHC_CABAL_INPLACE)" install \
		 $(INSTALLED_GHC_REAL) \
		 $(INSTALLED_GHC_PKG_REAL) \
		 $(DESTDIR)$(topdir) \
		 libraries/$p dist-install \
		 '$(DESTDIR)' '$(prefix)' '$(ghclibdir)' '$(docdir)/html/libraries' \
		 $(RelocatableBuild) &&) true
	$(foreach p, $(HIDDEN_PACKAGES),\
	    $(INSTALLED_GHC_PKG_REAL) --global-conf $(INSTALLED_PACKAGE_CONF) \
	                              hide $p &&) true
	"$(GHC_CABAL_INPLACE)" install \
		 $(INSTALLED_GHC_REAL) \
	 	 $(INSTALLED_GHC_PKG_REAL) \
		 $(DESTDIR)$(topdir) \
		 compiler stage2 \
		 '$(DESTDIR)' '$(prefix)' '$(ghclibdir)' '$(docdir)/html/libraries' \
		 $(RelocatableBuild)

# -----------------------------------------------------------------------------
# Binary distributions

ifneq "$(CLEANING)" "YES"
# This rule seems to hold some files open on Windows which prevents
# cleaning, perhaps due to the $(wildcard).

$(eval $(call bindist,.,\
    LICENSE \
    configure config.sub config.guess install-sh \
    extra-gcc-opts.in \
    Makefile \
    mk/config.mk.in \
    $(INPLACE_BIN)/mkdirhier \
    $(INPLACE_BIN)/ghc-cabal \
    utils/ghc-pwd/ghc-pwd \
	$(BINDIST_WRAPPERS) \
	$(BINDIST_LIBS) \
	$(BINDIST_HI) \
	$(BINDIST_EXTRAS) \
	$(includes_H_CONFIG) \
	$(includes_H_PLATFORM) \
	includes/ghcconfig.h \
	includes/rts/Config.h \
    $(INSTALL_HEADERS) \
    $(INSTALL_LIBEXECS) \
    $(INSTALL_LIBEXEC_SCRIPTS) \
    $(INSTALL_TOPDIRS) \
    $(INSTALL_TOPDIR_SCRIPTS) \
    $(INSTALL_BINS) \
    $(INSTALL_DOCS) \
    $(INSTALL_LIBRARY_DOCS) \
    $(addsuffix /*,$(INSTALL_HTML_DOC_DIRS)) \
	docs/index.html \
	$(wildcard libraries/*/dist-install/doc/) \
    $(filter-out extra-gcc-opts,$(INSTALL_LIBS)) \
    $(filter-out %/project.mk mk/config.mk %/mk/install.mk,$(MAKEFILE_LIST)) \
	mk/fix_install_names.sh \
	mk/project.mk \
	mk/install.mk.in \
	bindist.mk \
	libraries/dph/LICENSE \
 ))
endif
# mk/project.mk gets an absolute path, so we manually include it in
# the bindist with a relative path

BIN_DIST_MK = $(BIN_DIST_PREP_DIR)/bindist.mk

unix-binary-dist-prep:
	"$(RM)" $(RM_OPTS) -r bindistprep/*
	mkdir $(BIN_DIST_PREP_DIR)
	set -e; for i in LICENSE compiler ghc rts libraries utils docs libffi includes driver mk rules Makefile aclocal.m4 config.sub config.guess install-sh extra-gcc-opts.in ghc.mk inplace; do ln -s ../../$$i $(BIN_DIST_PREP_DIR)/; done
	echo "HADDOCK_DOCS       = $(HADDOCK_DOCS)"       >> $(BIN_DIST_MK)
	echo "LATEX_DOCS         = $(LATEX_DOCS)"         >> $(BIN_DIST_MK)
	echo "BUILD_DOCBOOK_HTML = $(BUILD_DOCBOOK_HTML)" >> $(BIN_DIST_MK)
	echo "BUILD_DOCBOOK_PS   = $(BUILD_DOCBOOK_PS)"   >> $(BIN_DIST_MK)
	echo "BUILD_DOCBOOK_PDF  = $(BUILD_DOCBOOK_PDF)"  >> $(BIN_DIST_MK)
	ln -s ../../distrib/configure-bin.ac $(BIN_DIST_PREP_DIR)/configure.ac
	cd $(BIN_DIST_PREP_DIR) && autoreconf
	"$(RM)" $(RM_OPTS) $(BIN_DIST_PREP_TAR)
# h means "follow symlinks", e.g. if aclocal.m4 is a symlink to a source
# tree then we want to include the real file, not a symlink to it
	cd bindistprep && "$(TAR)" hcf - -T ../$(BIN_DIST_LIST) | bzip2 -c > ../$(BIN_DIST_PREP_TAR_BZ2)

windows-binary-dist-prep:
	"$(RM)" $(RM_OPTS) -r bindistprep/*
	$(MAKE) prefix=$(TOP)/$(BIN_DIST_PREP_DIR) install
	cd bindistprep && "$(TAR)" cf - $(BIN_DIST_NAME) | bzip2 -c > ../$(BIN_DIST_PREP_TAR_BZ2)

windows-installer:
	"$(ISCC)" /O. /F$(WINDOWS_INSTALLER_BASE) - < distrib/ghc.iss

nTimes = set -e; for i in `seq 1 $(1)`; do echo Try "$$i: $(2)"; if $(2); then break; fi; done

.PHONY: publish-binary-dist
publish-binary-dist:
	$(call nTimes,10,$(PublishCp) $(BIN_DIST_TAR_BZ2) $(PublishLocation)/dist)
ifeq "$(mingw32_TARGET_OS)" "1"
	$(call nTimes,10,$(PublishCp) $(WINDOWS_INSTALLER) $(PublishLocation)/dist)
endif

.PHONY: publish-docs
publish-docs:
	$(call nTimes,10,$(PublishCp) -r bindisttest/installed/share/doc/ghc/* $(PublishLocation)/docs)

# -----------------------------------------------------------------------------
# Source distributions

# Do it like this:
#
#	$ make
#	$ make sdist
#

# A source dist is built from a complete build tree, because we
# require some extra files not contained in a darcs checkout: the
# output from Happy and Alex, for example.
#
# The steps performed by 'make dist' are as follows:
#   - create a complete link-tree of the current build tree in /tmp
#   - run 'make distclean' on that tree
#   - remove a bunch of other files that we know shouldn't be in the dist
#   - tar up first the extralibs package, then the main source package

#
# Directory in which we're going to build the src dist
#
SRC_DIST_NAME=ghc-$(ProjectVersion)
SRC_DIST_DIR=$(shell pwd)/$(SRC_DIST_NAME)

#
# Files to include in source distributions
#
SRC_DIST_DIRS = mk rules docs distrib bindisttest libffi includes utils docs rts compiler ghc driver libraries
SRC_DIST_FILES += \
	configure.ac config.guess config.sub configure \
	aclocal.m4 README ANNOUNCE HACKING LICENSE Makefile install-sh \
	ghc.spec.in ghc.spec extra-gcc-opts.in VERSION \
	boot boot-pkgs packages ghc.mk

SRC_DIST_TARBALL = $(SRC_DIST_NAME)-src.tar.bz2

VERSION :
	echo $(ProjectVersion) >VERSION

sdist : VERSION

# Use:
#     $(call sdist_file,compiler,stage2,cmm,CmmLex,x)
# to copy the generated file that replaces compiler/cmm/CmmLex.x, where
# "stage2" is the dist dir.
sdist_file = \
  if test -f $(TOP)/$1/$2/build/$4.hs; then \
    "$(CP)" $(TOP)/$1/$2/build/$4.hs $1/$3/ ; \
    mv $1/$3/$4.$5 $1/$3/$4.$5.source ;\
  else \
    echo "does not exist: $1/$2/build/$4.hs"; \
    exit 1; \
  fi

.PHONY: sdist-prep
sdist-prep :
	"$(RM)" $(RM_OPTS) -r $(SRC_DIST_DIR)
	"$(RM)" $(RM_OPTS) $(SRC_DIST_TARBALL)
	mkdir $(SRC_DIST_DIR)
	cd $(SRC_DIST_DIR) && for i in $(SRC_DIST_DIRS); do mkdir $$i; ( cd $$i && lndir $(TOP)/$$i ); done
	cd $(SRC_DIST_DIR) && for i in $(SRC_DIST_FILES); do $(LN_S) $(TOP)/$$i .; done
	cd $(SRC_DIST_DIR) && $(MAKE) distclean
	cd $(SRC_DIST_DIR) && if test -f $(TOP)/libraries/haskell-src/dist/build/Language/Haskell/Parser.hs; then "$(CP)" $(TOP)/libraries/haskell-src/dist/build/Language/Haskell/Parser.hs libraries/haskell-src/Language/Haskell/ ; mv libraries/haskell-src/Language/Haskell/Parser.ly libraries/haskell-src/Language/Haskell/Parser.ly.source ; fi
	cd $(SRC_DIST_DIR) && $(call sdist_file,compiler,stage2,cmm,CmmLex,x)
	cd $(SRC_DIST_DIR) && $(call sdist_file,compiler,stage2,cmm,CmmParse,y)
	cd $(SRC_DIST_DIR) && $(call sdist_file,compiler,stage2,parser,Lexer,x)
	cd $(SRC_DIST_DIR) && $(call sdist_file,compiler,stage2,parser,Parser,y.pp)
	cd $(SRC_DIST_DIR) && $(call sdist_file,compiler,stage2,parser,ParserCore,y)
	cd $(SRC_DIST_DIR) && $(call sdist_file,utils/hpc,dist,,HpcParser,y)
	cd $(SRC_DIST_DIR) && $(call sdist_file,utils/genprimopcode,dist,,Lexer,x)
	cd $(SRC_DIST_DIR) && $(call sdist_file,utils/genprimopcode,dist,,Parser,y)
	cd $(SRC_DIST_DIR) && "$(RM)" $(RM_OPTS) -r compiler/stage[123] mk/build.mk
	cd $(SRC_DIST_DIR) && "$(FIND)" $(SRC_DIST_DIRS) \( -name _darcs -o -name SRC -o -name "autom4te*" -o -name "*~" -o -name ".cvsignore" -o -name "\#*" -o -name ".\#*" -o -name "log" -o -name "*-SAVE" -o -name "*.orig" -o -name "*.rej" -o -name "*-darcs-backup*" \) -print | xargs "$(RM)" $(RM_OPTS) -r

.PHONY: sdist
sdist : sdist-prep
	"$(TAR)" chf - $(SRC_DIST_NAME) 2>$src_log | bzip2 >$(TOP)/$(SRC_DIST_TARBALL)

sdist-manifest : $(SRC_DIST_TARBALL)
	tar tjf $(SRC_DIST_TARBALL) | sed "s|^ghc-$(ProjectVersion)/||" | sort >sdist-manifest

# Upload the distribution(s)
# Retrying is to work around buggy firewalls that corrupt large file transfers
# over SSH.
ifneq "$(PublishLocation)" ""
publish-sdist :
	$(call nTimes,10,$(PublishCp) $(SRC_DIST_TARBALL) $(PublishLocation)/dist)
endif

ifeq "$(BootingFromHc)" "YES"
SRC_CC_OPTS += -DNO_REGS -DUSE_MINIINTERPRETER -D__GLASGOW_HASKELL__=$(ProjectVersionInt)
endif

# -----------------------------------------------------------------------------
# Cleaning

.PHONY: clean

CLEAN_FILES += utils/ghc-pwd/ghc-pwd
CLEAN_FILES += utils/ghc-pwd/ghc-pwd.exe
CLEAN_FILES += utils/ghc-pwd/ghc-pwd.hi
CLEAN_FILES += utils/ghc-pwd/ghc-pwd.o
CLEAN_FILES += libraries/bootstrapping.conf
CLEAN_FILES += libraries/integer-gmp/cbits/GmpDerivedConstants.h
CLEAN_FILES += libraries/integer-gmp/cbits/mkGmpDerivedConstants

clean : clean_files clean_libraries

.PHONY: clean_files
clean_files :
	"$(RM)" $(RM_OPTS) $(CLEAN_FILES)

ifneq "$(NO_CLEAN_GMP)" "YES"
CLEAN_FILES += libraries/integer-gmp/gmp/gmp.h
CLEAN_FILES += libraries/integer-gmp/gmp/libgmp.a

clean : clean_gmp
.PHONY: clean_gmp
clean_gmp:
	"$(RM)" $(RM_OPTS) -r libraries/integer-gmp/gmp/objs
	"$(RM)" $(RM_OPTS) -r libraries/integer-gmp/gmp/gmpbuild
endif

.PHONY: clean_libraries
clean_libraries: $(patsubst %,clean_libraries/%_dist-install,$(PACKAGES) $(PACKAGES_STAGE2))
clean_libraries: $(patsubst %,clean_libraries/%_dist-boot,$(BOOT_PKGS))

clean_libraries:
	"$(RM)" $(RM_OPTS) -r $(patsubst %, libraries/%/dist, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/*.buildinfo, $(PACKAGES) $(PACKAGES_STAGE2))

# We have to define a clean target for each library manually, because the
# libraries/*/ghc.mk files are not included when we're cleaning.
ifeq "$(CLEANING)" "YES"
$(foreach lib,$(PACKAGES) $(PACKAGES_STAGE2),\
  $(eval $(call clean-target,libraries/$(lib),dist-install,libraries/$(lib)/dist-install)))
endif

distclean : clean
	"$(RM)" $(RM_OPTS) config.cache config.status config.log mk/config.h mk/stamp-h
	"$(RM)" $(RM_OPTS) mk/config.mk mk/are-validating.mk mk/project.mk
	"$(RM)" $(RM_OPTS) mk/config.mk.old mk/project.mk.old
	"$(RM)" $(RM_OPTS) extra-gcc-opts docs/users_guide/ug-book.xml
	"$(RM)" $(RM_OPTS) compiler/ghc.cabal compiler/ghc.cabal.old
	"$(RM)" $(RM_OPTS) ghc/ghc-bin.cabal
	"$(RM)" $(RM_OPTS) libraries/base/include/HsBaseConfig.h
	"$(RM)" $(RM_OPTS) libraries/directory/include/HsDirectoryConfig.h
	"$(RM)" $(RM_OPTS) libraries/process/include/HsProcessConfig.h
	"$(RM)" $(RM_OPTS) libraries/unix/include/HsUnixConfig.h
	"$(RM)" $(RM_OPTS) libraries/old-time/include/HsTimeConfig.h

	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/config.log, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/config.status, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/include/Hs*Config.h, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) -r $(patsubst %, libraries/%/autom4te.cache, $(PACKAGES) $(PACKAGES_STAGE2))

maintainer-clean : distclean
	"$(RM)" $(RM_OPTS) configure mk/config.h.in
	"$(RM)" $(RM_OPTS) -r autom4te.cache libraries/*/autom4te.cache
	"$(RM)" $(RM_OPTS) ghc.spec
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/GNUmakefile, \
	        $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/ghc.mk, $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) $(patsubst %, libraries/%/configure, \
	        $(PACKAGES) $(PACKAGES_STAGE2))
	"$(RM)" $(RM_OPTS) libraries/base/include/HsBaseConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/directory/include/HsDirectoryConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/process/include/HsProcessConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/unix/include/HsUnixConfig.h.in
	"$(RM)" $(RM_OPTS) libraries/old-time/include/HsTimeConfig.h.in

.PHONY: all_libraries

.PHONY: bootstrapping-files
bootstrapping-files: $(OTHER_LIBS)
bootstrapping-files: includes/ghcautoconf.h
bootstrapping-files: includes/DerivedConstants.h
bootstrapping-files: includes/GHCConstants.h

.DELETE_ON_ERROR:

