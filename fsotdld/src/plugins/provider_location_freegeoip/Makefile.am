include $(top_srcdir)/Makefile.decl
NULL =

AM_CFLAGS = \
	-DG_LOG_DOMAIN=\"fsotdld.provider_location_freegeoip\" \
	$(NULL)
AM_VALAFLAGS =

modlibexecdir = $(libdir)/cornucopia/modules/fsotdl
modlibexec_LTLIBRARIES = provider_location_freegeoip.la
provider_location_freegeoip_la_SOURCES = plugin.vala
provider_location_freegeoip_la_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir $(top_srcdir)/src/lib \
	--pkg posix \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg fso-glib-1.0 \
	--pkg fsoframework-2.0 \
	--pkg fsotransport-2.0 \
	--pkg fsoresource-2.0 \
	--pkg fsotdl-2.0 \
	$(DEBUG_VALAFLAGS) \
	$(NULL)
provider_location_freegeoip_la_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	$(FSO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(DEBUG_CFLAGS) \
	$(NULL)
provider_location_freegeoip_la_LIBADD = \
	$(FSO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/src/lib/libfsotdl.la \
	$(NULL)
provider_location_freegeoip_la_LDFLAGS = -no-undefined -module -avoid-version
# provider_location_freegeoip_la_LIBTOOLFLAGS = --tag=disable-static

CLEANFILES =
MAINTAINERCLEANFILES = \
  Makefile.in \
  $(NULL)
