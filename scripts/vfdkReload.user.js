// ==UserScript==
// @name         VFDK - Auto Reboot
// @version      2024-04-22
// @description  Automatically refresh VFDK test.
// @author       Joshua Lawrence
// @match        http://*/wtftest.pl?target_sn=*
// @downloadURL  https://github.com/JoshuaALawrence/joshuaalawrence.github.io/raw/main/scripts/vfdkReload.user.js
// @updateURL    https://github.com/JoshuaALawrence/joshuaalawrence.github.io/raw/main/scripts/vfdkReload.user.js
// @grant        GM_xmlhttpRequest
// @grant        GM_setValue
// @grant        GM_getValue
// ==/UserScript==

(function() {
    'use strict';

    var PageName = GM_getValue(window.location.href.split("&")[0])

    // Refresh automatically to show warnings and errors
    var url = window.location.href.replace("actual_Show_Warnings=0", "actual_Show_Warnings=1").replace("actual_Show_Errors=0", "actual_Show_Errors=1");
    if (!url.includes("actual_Show_Warnings")) {
        window.location.replace(window.location.href + ";Embed%20Errors=on;Embed%20Warnings=on;Show%20Passes=on;Show%20Warnings=on;Show%20Errors=on;Show%20BOM%20Changes=on;Refresh%20Data=do_refresh;actual_Embed_Results=0;actual_Embed_Errors=1;actual_Embed_Bypasses=0;actual_Embed_Warnings=1;actual_Show_Passes=1;actual_Show_Warnings=1;actual_Show_Errors=1;actual_Show_BOM_Changes=1")
    }

    // Setup initial menu bar
    const menuBar = document.createElement('div');
    menuBar.style.cssText = `
        position: fixed;
        bottom: 0;
        left: 0;
        right: 0;
        background: #2D2D2D;
        color: white;
        z-index: 10000;
        padding: 5px 15px;
        box-shadow: 0 -2px 5px rgba(0,0,0,0.2);
        font-family: Arial, sans-serif;
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-top: 1px solid #444;
        box-sizing: border-box;
    `;
    menuBar.innerHTML = `
        <input id="floaterInput" type="text" style="
            flex-grow: 1;
            margin-right: 10px;
            padding: 4px 8px;
            padding-left: 4px;  /* Reduced left padding for more text space */
            background: #404040;
            border: 1px solid #555;
            color: white;
            border-radius: 4px;
            font-size: 14px;
            outline: none;  /* Removes the glow effect on focus */
        " placeholder="Type what you want this test to be called when notified." />
        <button id="confirmButton" style="
            padding: 4px 8px;
            background-color: #5C5C5C;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            outline: none;
        ">Confirm</button>
        <button id="closeButton" style="
            padding: 4px 8px;
            margin-left: 5px;
            background-color: #888;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
            font-weight: bold;
            outline: none;
        ">X</button>
    `;
    document.body.appendChild(menuBar);
    document.body.style.paddingBottom = `${menuBar.offsetHeight}px`;
    document.getElementById('floaterInput').addEventListener('keyup', function(event) {
        if (event.key === "Enter") {
            document.getElementById('confirmButton').click();
        }
    });
    document.getElementById('closeButton').addEventListener('click', function() {
        menuBar.remove();
    });
    document.body.prepend(menuBar);
    document.body.style.paddingBottom = `${menuBar.offsetHeight}px`;
    if (PageName) {
        document.getElementById("floaterInput").value = PageName;
    }
    // Start of the script
    document.getElementById('confirmButton').addEventListener('click', function() {
        const floaterValue = floaterInput.value.trim();
        if (floaterValue === "") {
            window.Floater = window.location.href.match(/target_sn=(\d+)/i);
            if (window.Floater.length > 0) {
                window.Floater = window.Floater[1]
            }
        }
        menuBar.remove();
        window.Floater = floaterValue;
        GM_setValue(window.location.href.split("&")[0], window.Floater);
        console.log(`Floater type confirmed as: ${window.Floater}`);
        if (window.ScriptRunning) return;

        window.ScriptRunning = true;
        window.PreviousErrors = [];

        document.querySelector("input[name='Refresh Data']")?.remove();

        const style = document.createElement('style');
        style.textContent = `
        .custom-notification {
            position: fixed; bottom: 20px; left: 50%;
            transform: translateX(-50%); padding: 15px 30px;
            background-color: #323232; color: #fff;
            border-radius: 5px; box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
            font-size: 16px; z-index: 10000; opacity: 1;
            transition: opacity 0.5s;
        }
    `;
        document.head.append(style);

        function showNotification(message, duration = 3000) {
            const notification = document.createElement('div');
            notification.className = 'custom-notification';
            notification.textContent = message;
            document.body.append(notification);
            setTimeout(() => notification.style.opacity = '0', duration - 500);
            setTimeout(() => document.body.removeChild(notification), duration);
        }

        showNotification("Now updating VFDK every 15 seconds.");

        setInterval(() => {
            document.title = "Updating..";
            var url = window.location.href.replace("actual_Show_Warnings=0", "actual_Show_Warnings=1").replace("actual_Show_Errors=0", "actual_Show_Errors=1");
            if (!url.includes("actual_Show_Warnings")) {
                url += ";Embed%20Errors=on;Embed%20Warnings=on;Show%20Passes=on;Show%20Warnings=on;Show%20Errors=on;Show%20BOM%20Changes=on;Refresh%20Data=do_refresh;actual_Embed_Results=0;actual_Embed_Errors=1;actual_Embed_Bypasses=0;actual_Embed_Warnings=1;actual_Show_Passes=1;actual_Show_Warnings=1;actual_Show_Errors=1;actual_Show_BOM_Changes=1"
            }
            fetch(url)
                .then(response => response.ok ? response.text() : Promise.reject('Network response was not ok'))
                .then(htmlContent => {
                    window.beep = function() {
                        var snd = new Audio("data:audio/wav;base64,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qJrx4KOQjahZxWbcZgztj2c49nKmkId44S71j0c8eV9yDK6uPRzx5X18eDvjvQ6yKo9ZSS6l//8elePK/Lf//IInrOF/FvDoADYAGBMGb7FtErm5MXMlmPAJQVgWta7Zx2go+8xJ0UiCb8LHHdftWyLJE0QIAIsI+UbXu67dZMjmgDGCGl1H+vpF4NSDckSIkk7Vd+sxEhBQMRU8j/12UIRhzSaUdQ+rQU5kGeFxm+hb1oh6pWWmv3uvmReDl0UnvtapVaIzo1jZbf/pD6ElLqSX+rUmOQNpJFa/r+sa4e/pBlAABoAAAAA3CUgShLdGIxsY7AUABPRrgCABdDuQ5GC7DqPQCgbbJUAoRSUj+NIEig0YfyWUho1VBBBA//uQZB4ABZx5zfMakeAAAAmwAAAAF5F3P0w9GtAAACfAAAAAwLhMDmAYWMgVEG1U0FIGCBgXBXAtfMH10000EEEEEECUBYln03TTTdNBDZopopYvrTTdNa325mImNg3TTPV9q3pmY0xoO6bv3r00y+IDGid/9aaaZTGMuj9mpu9Mpio1dXrr5HERTZSmqU36A3CumzN/9Robv/Xx4v9ijkSRSNLQhAWumap82WRSBUqXStV/YcS+XVLnSS+WLDroqArFkMEsAS+eWmrUzrO0oEmE40RlMZ5+ODIkAyKAGUwZ3mVKmcamcJnMW26MRPgUw6j+LkhyHGVGYjSUUKNpuJUQoOIAyDvEyG8S5yfK6dhZc0Tx1KI/gviKL6qvvFs1+bWtaz58uUNnryq6kt5RzOCkPWlVqVX2a/EEBUdU1KrXLf40GoiiFXK///qpoiDXrOgqDR38JB0bw7SoL+ZB9o1RCkQjQ2CBYZKd/+VJxZRRZlqSkKiws0WFxUyCwsKiMy7hUVFhIaCrNQsKkTIsLivwKKigsj8XYlwt/WKi2N4d//uQRCSAAjURNIHpMZBGYiaQPSYyAAABLAAAAAAAACWAAAAApUF/Mg+0aohSIRobBAsMlO//Kk4soosy1JSFRYWaLC4qZBYWFRGZdwqKiwkNBVmoWFSJkWFxX4FFRQWR+LsS4W/rFRb/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////VEFHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAU291bmRib3kuZGUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMjAwNGh0dHA6Ly93d3cuc291bmRib3kuZGUAAAAAAAAAACU=");
                        snd.play();
                    }
                    window.createTeamsMessage = function(errors) {
                        let messageText = errors.join("<br><br>");
                        const maxLength = 28000; // Assuming 28,000 characters is the Teams limit

                        // Check if the message exceeds the maximum length
                        while (new TextEncoder().encode(messageText).length > maxLength && errors.length > 0) {
                            errors.shift(); // Remove the oldest error
                            messageText = errors.join("<br><br>"); // Rebuild the message
                        }

                        return {
                            "@type": "MessageCard",
                            "@context": "http://schema.org/extensions",
                            "text": messageText.trim()
                        };
                    }
                    window.showNotification = function(message, duration = 3000) {
                        const notification = document.createElement('div');
                        notification.className = 'custom-notification';
                        notification.textContent = message;
                        document.body.append(notification);
                        setTimeout(() => notification.style.opacity = '0', duration - 500);
                        setTimeout(() => document.body.removeChild(notification), duration);
                    }

                    window.flashScreen = function() {
                        const overlay = document.createElement('div');
                        overlay.style.position = 'fixed';
                        overlay.style.top = '0';
                        overlay.style.left = '0';
                        overlay.style.width = '100%';
                        overlay.style.height = '100%';
                        overlay.style.backgroundColor = 'red';
                        overlay.style.zIndex = '9999';
                        document.body.appendChild(overlay);
                        let isFlashing = false;
                        const flashDuration = 200;
                        const totalDuration = 2000;
                        const interval = setInterval(() => {
                            overlay.style.display = isFlashing ? 'none' : 'block';
                            isFlashing = !isFlashing;
                        }, flashDuration);
                        setTimeout(() => {
                            clearInterval(interval);
                            try {
                                document.body.removeChild(overlay);
                            } catch {}
                        }, totalDuration);
                    };

                    document.documentElement.innerHTML = htmlContent.replace(/<input.*?Refresh Data.*?>/i, "");

                    Array.from(document.querySelectorAll("tr")).forEach(a => {
                        if (a.children.length >= 13 && parseInt(a.children[13].innerHTML)) {
                            if (parseInt(a.children[13].innerHTML) >= 60) {
                                a.children[13].innerHTML = "<strong>" + (Math.round(parseInt(a.children[13].innerHTML) / 60).toString()) + " Min</strong>"
                            }
                        }
                    });

                    Array.from(document.querySelectorAll("pre")).forEach(e => {
                        const Value = e.textContent;
                        const aValue = [...new Set(Value.split(/\r?\n/i))];
                        e.textContent = aValue.join("\n");
                    });

                    const errorMatches = (htmlContent.match(/Failure:.*?($|\n|\r)/gi) || []);
                    const newErrors = [];

                    var SN = window.location.href.match(/target_sn=(\d+)/i);
                    if (SN.length > 0) {
                        SN = SN[1]
                    }

                    errorMatches.forEach(error => {
                        const previousCount = window.PreviousErrors.filter(e => e === error).length;
                        const currentCount = errorMatches.filter(e => e === error).length;

                        if (currentCount > previousCount && !error.match(/System does not contain old fans./i)) {
                            newErrors.push(...Array(currentCount - previousCount).fill(error));
                        }
                    });

                    window.PreviousErrors = errorMatches;

                    if (newErrors.length > 0) {
                        window.flashScreen();
                        window.beep();
                        setTimeout(() => {
                            window.beep()
                        }, 250);
                        setTimeout(() => {
                            window.beep()
                        }, 250);
                        window.showNotification("You have " + newErrors.length + " new errors.");

                        let uniqueNewErrors = [`[<span style='color:#D22B2B;'><b> ${window.Floater ? window.Floater : SN} </b></span>]`, ...Array.from(new Set(newErrors))];
                        uniqueNewErrors = uniqueNewErrors.map(error => error.replace(/^Failure/g, "<b><span style='color:#D22B2B;'>Failure</span></b>"));
                        const messagePayload = window.createTeamsMessage(uniqueNewErrors);

                        GM_xmlhttpRequest({
                            method: "POST",
                            url: "https://ztgroup.webhook.office.com/webhookb2/ac118ee4-10a1-4a48-bf28-6113e5332d1b@456511db-ed57-4e12-aeab-e9fcdcccfca4/IncomingWebhook/b4c67a7ec84447c69240fdcabe03e188/ad96ba98-4259-4834-841a-bc89209cf158",
                            headers: {
                                "Content-Type": "application/json"
                            },
                            data: JSON.stringify(messagePayload),
                            onload: response => console.log('Success:', response.responseText),
                            onerror: response => console.error('Error:', response.statusText)
                        });
                    }

                    const lastAction = document.evaluate('/html/body/table[3]/tbody/tr[2]/td[12]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
                    const lastTest = document.evaluate('/html/body/table[3]/tbody/tr[2]/td[4]', document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;

                    if (typeof lastAction != "undefined" && lastAction && typeof lastTest != "undefined" && lastTest && (window.lastTest != lastTest.textContent || window.lastAction != lastAction.textContent) && (lastAction.textContent.match(/(exit|reboot)/i) || lastTest.textContent.match(/test-?end/i)) && SN.length >= 2) {
                        window.lastTest = lastTest.textContent;
                        window.lastAction = lastAction.textContent;

                        const changePayload = {
                            "@type": "MessageCard",
                            "@context": "http://schema.org/extensions",
                            "text": `[<b>${window.lastTest == lastTest.textContent.match(/(test-?end)/i) || lastAction.textContent.match(/.*?flip.*?/i) ? "<span style='color:#50C878;'>" : "<span style='color:#D22B2B;'>"} ${window.Floater ? window.Floater : SN} </span></b>]<br><b>Action</b>: ${lastAction.textContent}<br><b>Test</b>: ${lastTest.textContent}`
                        };
                        GM_xmlhttpRequest({
                            method: "POST",
                            url: "https://ztgroup.webhook.office.com/webhookb2/ac118ee4-10a1-4a48-bf28-6113e5332d1b@456511db-ed57-4e12-aeab-e9fcdcccfca4/IncomingWebhook/b4c67a7ec84447c69240fdcabe03e188/ad96ba98-4259-4834-841a-bc89209cf158",
                            headers: {
                                "Content-Type": "application/json"
                            },
                            data: JSON.stringify(changePayload),
                            onload: response => console.log('Action/Test Change Notification Sent:', response.responseText),
                            onerror: response => console.error('Error Sending Action/Test Change Notification:', response.statusText)
                        });
                    }
                }).catch(error => console.error('Error fetching the data:', error));
        }, 15000);
    });
})();
