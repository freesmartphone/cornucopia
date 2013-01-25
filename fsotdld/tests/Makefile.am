include $(top_srcdir)/Makefile.decl

NULL =

AM_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(FSO_CFLAGS) \
	$(NULL)

noinst_PROGRAMS = $(TEST_PROGS)

LDADD = \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(FSO_LIBS) \
	$(top_builddir)/src/lib/libfsotdl.la

AM_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir $(top_srcdir)/src/lib \
	--pkg posix \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-1.0 \
	--pkg fsoframework-2.0 \
	--pkg fsotdl-2.0

TEST_PROGS += testsourcentp
testsourcentp_SOURCES = \
	testsourcentp.vala \
	$(top_srcdir)/src/plugins/source_ntp/plugin.vala

CLEANFILES =
MAINTAINERCLEANFILES = \
  Makefile.in \
  $(NULL)
