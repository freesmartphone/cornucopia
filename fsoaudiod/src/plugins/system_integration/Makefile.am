include $(top_srcdir)/Makefile.decl
NULL =

AM_CFLAGS = \
	-include $(CONFIG_HEADER) \
	-DG_LOG_DOMAIN=\"fsoaudio\" \
	$(NULL)
AM_VALAFLAGS =


modlibexecdir = $(libdir)/cornucopia/modules/fsoaudio
modlibexec_LTLIBRARIES = system_integration.la
system_integration_la_SOURCES = plugin.vala
system_integration_la_VALAFLAGS = \
	--basedir $(top_srcdir) \
	--vapidir $(top_srcdir)/src/lib \
	--vapidir $(top_srcdir)/vapi \
	--pkg glib-2.0 \
	--pkg gee-0.8 \
	--pkg fso-glib-1.0 \
	--pkg fsoframework-2.0 \
	--pkg fsoaudio-2.0 \
	$(DEBUG_VALAFLAGS) \
	$(NULL)
system_integration_la_CFLAGS = \
	-I$(top_srcdir)/src/lib \
	$(FSO_GLIB_CFLAGS) \
	$(FSO_CFLAGS) \
	$(GLIB_CFLAGS) \
	$(GEE_CFLAGS) \
	$(DEBUG_CFLAGS) \
	$(NULL)
system_integration_la_LIBADD = \
	$(FSO_GLIB_LIBS) \
	$(FSO_LIBS) \
	$(GLIB_LIBS) \
	$(GEE_LIBS) \
	$(top_builddir)/src/lib/libfsoaudio.la \
	$(NULL)
system_integration_la_LDFLAGS = -no-undefined -module -avoid-version
# system_integration_la_LIBTOOLFLAGS = --tag=disable-static
