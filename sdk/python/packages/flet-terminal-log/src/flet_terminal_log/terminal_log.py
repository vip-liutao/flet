from typing import Optional

import flet as ft

@ft.control("TerminalLog")
class TerminalLog(ft.LayoutControl):

    on_data_channel_open: Optional[ft.EventHandler[ft.DataChannelOpenEvent]] = None
    on_data_channel_close: Optional[ft.EventHandler[ft.DataChannelOpenEvent]] = None

    def init(self) -> None:
        self._channel: Optional[ft.DataChannel] = None
        if self.on_data_channel_open is None:
            self.on_data_channel_open = self._data_channel_open

    def _data_channel_open(self, e: ft.DataChannelOpenEvent) -> None:
        self._channel = self.get_data_channel(e.channel_id)

    async def push_frame(self, text_bytes: bytes) -> None:
        assert self._channel is not None
        self._channel.send(text_bytes)
