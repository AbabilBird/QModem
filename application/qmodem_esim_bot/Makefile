include $(TOPDIR)/rules.mk

include ../../version.mk

PKG_NAME:=qmodem-esim-bot
PKG_VERSION:=$(QMODEM_VERSION)
PKG_RELEASE:=$(QMODEM_RELEASE)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  PKGARCH:=all
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Telegram bot for QModem eSIM management
  DEPENDS:=+curl +jq +lpac
  URL:=https://github.com/mkuruyuk/QModem
endef

define Package/$(PKG_NAME)/description
  Telegram bot for remote eSIM profile management on OpenWrt.
  Supports: profile list, switch, download, delete, modem status.
  Uses long-polling (no webhook server needed).
  Zero additional dependencies beyond curl and jq.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/qmodem_esim_bot
endef

define Build/Prepare
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/qmodem-esim-bot $(1)/usr/bin/qmodem-esim-bot

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/qmodem_esim_bot $(1)/etc/config/qmodem_esim_bot

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/qmodem_esim_bot $(1)/etc/init.d/qmodem_esim_bot
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
