include $(top_srcdir)/Makefile.decl
NULL =

AM_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	$(FSO_GLIB_CFLAGS) \
	$(FSO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NULL)

noinst_PROGRAMS = $(TEST_PROGS)

progs_ldadd = \
	$(FSO_GLIB_LIBS) \
	$(FSO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_srcdir)/src/lib/libfsopreferences.la

VALAC_ARGS = \
	--basedir $(top_srcdir) \
	--vapidir ../../lib \
	--pkg glib-2.0 \
	--pkg gee-0.8 \
	--pkg fso-glib-1.0 \
	--pkg fsoframework-2.0 \
	--pkg fsopreferences-2.0

if WANT_DEBUG
VALAC_ARGS += -g -D DEBUG
AM_CFLAGS += -ggdb -O0
endif

#
# plugin
#
modlibexecdir = $(libdir)/cornucopia/modules/fsopreferences
modlibexec_LTLIBRARIES = manager.la
manager_la_SOURCES = plugin.c
manager_la_VALASOURCES = plugin.vala
$(manager_la_SOURCES): $(manager_la_VALASOURCES)
	$(VALAC) -C $(VALAC_ARGS) $^
	touch $@
manager_la_LIBADD = $(progs_ldadd)
manager_la_LDFLAGS = -no-undefined -module -avoid-version
manager_la_LIBTOOLFLAGS = --tag=disable-static

CLEANFILES = \
    *.c \
    *.h \
    *.la \
    *.lo \
    $(NULL)

MAINTAINERCLEANFILES = \
  Makefile.in \
$(NULL)
