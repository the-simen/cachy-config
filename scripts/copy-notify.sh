#!/bin/sh

#!/bin/sh

wl-paste --watch sh -c '
    [ "$CLIPBOARD_STATE" = "data" ] || exit 0

    noctalia msg notification-show "{\"summary\":\"Clipboard\",\"body\":\"Selection copied\",\"icon\":\"clipboard\"}"
'
