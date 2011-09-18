include $(top_srcdir)/Makefile.decl
NULL =

AUTOMAKE_OPTIONS = subdir-objects

SUBDIRS = \
	manager \
	\
	router_palmpre \
	router_alsa \
	router_aci \
	\
	streamcontrol_alsa \
	sessionpolicy_default \
	\
	system_integration \
	\
	$(NULL)

if WANT_CMTSPEECHDATA
SUBDIRS += gsmvoice_alsa_cmtspeechdata
endif


