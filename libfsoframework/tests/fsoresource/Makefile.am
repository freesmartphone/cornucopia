include $(top_srcdir)/Makefile.decl

NULL =

AM_CFLAGS = \
	$(GLIB_CFLAGS) \
	-I$(top_srcdir) \
	-I$(top_srcdir)/fsoresource \
	$(NULL)

LDADD = \
	$(top_builddir)/fsoresource/libfsoresource.la \
	$(GLIB_LIBS)
	$(NULL)

AM_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir $(top_srcdir)/fsoresource \
	--pkg posix \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg fsoframework-2.0 \
	--pkg fsoresource-2.0 \
	$(NULL)

noinst_PROGRAMS = testresource
TEST_PROGS += $(noinst_PROGAMS)

testresource_SOURCES = testresource.vala

CLEANFILES = \
	$(TEST_PROGS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(addsuffix .c,$(noinst_PROGAMS)) \
	testresource_vala.stamp \
	$(NULL)

EXTRA_DIST += \
	$(MAINTAINERCLEANFILES) \
	$(NULL)