JULIAHOME = $(abspath .)
include $(JULIAHOME)/Make.inc

all: default
default: release

DIRS = usr/bin usr/etc usr/lib/julia

$(foreach dir,$(DIRS),$(eval $(call dir_target,$(dir))))
$(foreach link,extras base,$(eval $(call symlink_target,$(link),usr/lib)))

debug release: | $(DIRS) usr/lib/extras usr/lib/base
	@$(MAKE) -s julia-$@
	@$(MAKE) -s usr/lib/julia/sys.ji

julia-debug julia-release:
	@$(MAKE) -sC deps
	@$(MAKE) -sC src lib$@
	@$(MAKE) -sC base
	@$(MAKE) -sC ui $@
	@ln -sf usr/bin/$@-$(DEFAULT_REPL) julia

base/build_h.jl: Make.inc
	@echo "_jl_libblas_name = \"$(LIBBLASNAME)\"" > $@
	@echo "_jl_liblapack_name = \"$(LIBLAPACKNAME)\"" >> $@

usr/lib/julia/sys0.ji: base/boot.jl src/dump.c base/stage0.jl base/build_h.jl
	$(QUIET_JULIA) cd base && $(USRBIN)/julia-release-$(DEFAULT_REPL) -b stage0.jl
	@rm -f usr/lib/julia/sys.ji

# if sys.ji exists, use it to rebuild, otherwise use sys0.ji
usr/lib/julia/sys.ji: VERSION usr/lib/julia/sys0.ji base/*.jl
	$(QUIET_JULIA) cd base && ../julia `test -f $(JULIAHOME)/usr/lib/julia/sys.ji && echo stage1.jl || echo -J $(JULIAHOME)/usr/lib/julia/sys0.ji stage1.jl`

DESTDIR = julia-$(JULIA_COMMIT)
install: release
	mkdir -p $(DESTDIR)/{sbin,bin,etc,lib/julia/webserver,lib/julia/website}
	cp usr/bin/*julia* $(DESTDIR)/bin
	cp usr/lib/julia/sys.ji $(DESTDIR)/lib/julia
	cp usr/lib/lib{Rmath,amd,amos,arpack,cholmod,colamd,fdm,fftw3,fftw3f,fftw3_threads,fftw3f_threads,glpk,glpk_wrapper,gmp,gmp_wrapper,grisu,history,julia-release,openblas,pcre,random,readline,suitesparse_wrapper,umfpack}.$(SHLIB_EXT) $(DESTDIR)/lib
	cp -r base extras $(DESTDIR)/lib/julia
# Web-REPL stuff
	cp usr/lib/mod* $(DESTDIR)/lib
	cp usr/sbin/* $(DESTDIR)/sbin
	cp usr/etc/* $(DESTDIR)/etc
	cp ui/webserver/*.jl $(DESTDIR)/lib/julia/webserver
	cp ui/website/*.* $(DESTDIR)/lib/julia/website
	cp -r ui/website/assets $(DESTDIR)/lib/julia/website
	cp -r ui/website/images $(DESTDIR)/lib/julia/website

dist: release
	rm -fr dist julia-*.tar.gz julia-$(JULIA_COMMIT)
	$(MAKE) install
	tar zcvf julia-$(JULIA_COMMIT)-$(OS)-$(ARCH).tar.gz julia-$(JULIA_COMMIT)
	rm -fr julia-$(JULIA_COMMIT)

deb:
	fakeroot debian/rules binary

debclean:
	fakeroot debian/rules clean

h2j: usr/lib/libLLVM*.a usr/lib/libclang*.a src/h2j.cpp
	$(QUIET_CC) g++ -O2 -fno-rtti -D__STDC_LIMIT_MACROS -D__STDC_CONSTANT_MACROS -Iinclude $^ -o $@

clean:
	@rm -f julia-{release,debug}-{basic,readline,webserver}
	@rm -f *~ *# *.tar.gz
	@rm -fr usr/lib/julia
	@$(MAKE) -sC base clean
	@$(MAKE) -sC src clean
	@$(MAKE) -sC ui clean
	@$(MAKE) -sC ui/webserver clean
	@$(MAKE) -sC test/unicode clean

cleanall: clean
	@$(MAKE) -sC src clean-flisp clean-support
#	@$(MAKE) -sC deps clean-uv

.PHONY: default debug release julia-debug julia-release \
	test testall test-* sloccount clean cleanall

test: release
	@$(MAKE) -sC test default

testall: release
	@$(MAKE) -sC test all

test-%: release
	@$(MAKE) -sC test $*
