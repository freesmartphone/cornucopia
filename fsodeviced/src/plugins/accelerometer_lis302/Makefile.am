include $(top_srcdir)/Makefile.decl
NULL =

AM_CFLAGS = \
	-DG_LOG_DOMAIN=\"fsodevice.accelerometer_lis302\" \
	$(NULL)
AM_VALAFLAGS =

modlibexecdir = $(libdir)/cornucopia/modules/fsodevice
modlibexec_LTLIBRARIES = accelerometer_lis302.la
accelerometer_lis302_la_SOURCES = plugin.vala
accelerometer_lis302_la_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir ./ \
	--vapidir $(top_srcdir)/src/lib \
	--pkg linux \
	--pkg glib-2.0 \
	--pkg gee-0.8 \
	--pkg fsoframework-2.0 \
	--pkg fso-glib-1.0 \
	--pkg fsodevice-2.0 \
	$(DEBUG_VALAFLAGS) \
	$(NULL)
accelerometer_lis302_la_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	$(GLIB_CFLAGS) \
	$(FSO_CFLAGS) \
	$(DEBUG_CFLAGS) \
	$(NULL)
accelerometer_lis302_la_LIBADD = \
	$(top_builddir)/src/lib/libfsodevice.la \
	$(GLIB_LIBS) \
	$(FSO_LIBS) \
	$(NULL)
accelerometer_lis302_la_LDFLAGS = -no-undefined -module -avoid-version
# accelerometer_lis302_la_LIBTOOLFLAGS = --tag=disable-static

CLEANFILES =
MAINTAINERCLEANFILES = \
  Makefile.in \
  $(NULL)
