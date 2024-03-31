// ==UserScript==
// @name         VFDK
// @namespace    http://tampermonkey.net/
// @version      2024-03-24
// @description  try to take over the world!
// @author       You
// @match        http://192.168.7.7:1110/wtftest.pl?target_sn=*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=mozilla.org
// @grant        GM_xmlhttpRequest
// ==/UserScript==

(function() {
    'use strict';
	var Refresh_Button = document.querySelector("input[name='Refresh Data']");
	if (window.ScriptRunning == true) {
		showNotification("VFDK is already automatically updating.");
		return
	}
	window.ScriptRunning = true;
	window.Errors = 0;
	if (document.documentElement.innerHTML.match(/Failure:/g) != null) {
		window.Errors = document.documentElement.innerHTML.match(/Failure:/g).length;
	}
	if (Refresh_Button) { Refresh_Button.remove(); }
	const style = document.createElement('style');
	style.innerHTML = `
		.custom-notification {
			position: fixed;
			bottom: 20px;
			left: 50%;
			transform: translateX(-50%);
			padding: 15px 30px;
			background-color: #323232;
			color: #fff;
			border-radius: 5px;
			box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
			font-size: 16px;
			z-index: 10000;
			opacity: 1;
			transition: opacity 0.5s;
		}
	`;
	document.head.appendChild(style);
	function showNotification(message, duration = 3000) {
		let notification = document.createElement('div');
		notification.className = 'custom-notification';
		notification.textContent = message;
		document.body.appendChild(notification);
		setTimeout(() => {
			notification.style.opacity = '0';
			setTimeout(() => {
				try{
				document.body.removeChild(notification);
				}catch{
				}
			}, 500);
		}, duration);
	}
	showNotification("Now updating VFDK every 15 seconds.");
	const CheckingTest = setInterval(() => {
		document.title = "Updating..";
		var url = window.location.href.replace("actual_Show_Warnings=0", "actual_Show_Warnings=1");
		if (!url.includes("actual_Show_Warnings")) {
			url += ";Embed%20Errors=on;Embed%20Warnings=on;Show%20Passes=on;Show%20Warnings=on;Show%20Errors=on;Show%20BOM%20Changes=on;Refresh%20Data=do_refresh;actual_Embed_Results=0;actual_Embed_Errors=1;actual_Embed_Bypasses=0;actual_Embed_Warnings=1;actual_Show_Passes=1;actual_Show_Warnings=1;actual_Show_Errors=1;actual_Show_BOM_Changes=1"
		}
		fetch(url)
		.then(response => {
			if (!response.ok) {
				throw new Error('Network response was not ok');
			}
			return response.text();
		})
		.then(async (htmlContent) => {
			function beep() {
				var snd = new Audio("data:audio/wav;base64,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qJrx4KOQjahZxWbcZgztj2c49nKmkId44S71j0c8eV9yDK6uPRzx5X18eDvjvQ6yKo9ZSS6l//8elePK/Lf//IInrOF/FvDoADYAGBMGb7FtErm5MXMlmPAJQVgWta7Zx2go+8xJ0UiCb8LHHdftWyLJE0QIAIsI+UbXu67dZMjmgDGCGl1H+vpF4NSDckSIkk7Vd+sxEhBQMRU8j/12UIRhzSaUdQ+rQU5kGeFxm+hb1oh6pWWmv3uvmReDl0UnvtapVaIzo1jZbf/pD6ElLqSX+rUmOQNpJFa/r+sa4e/pBlAABoAAAAA3CUgShLdGIxsY7AUABPRrgCABdDuQ5GC7DqPQCgbbJUAoRSUj+NIEig0YfyWUho1VBBBA//uQZB4ABZx5zfMakeAAAAmwAAAAF5F3P0w9GtAAACfAAAAAwLhMDmAYWMgVEG1U0FIGCBgXBXAtfMH10000EEEEEECUBYln03TTTdNBDZopopYvrTTdNa325mImNg3TTPV9q3pmY0xoO6bv3r00y+IDGid/9aaaZTGMuj9mpu9Mpio1dXrr5HERTZSmqU36A3CumzN/9Robv/Xx4v9ijkSRSNLQhAWumap82WRSBUqXStV/YcS+XVLnSS+WLDroqArFkMEsAS+eWmrUzrO0oEmE40RlMZ5+ODIkAyKAGUwZ3mVKmcamcJnMW26MRPgUw6j+LkhyHGVGYjSUUKNpuJUQoOIAyDvEyG8S5yfK6dhZc0Tx1KI/gviKL6qvvFs1+bWtaz58uUNnryq6kt5RzOCkPWlVqVX2a/EEBUdU1KrXLf40GoiiFXK///qpoiDXrOgqDR38JB0bw7SoL+ZB9o1RCkQjQ2CBYZKd/+VJxZRRZlqSkKiws0WFxUyCwsKiMy7hUVFhIaCrNQsKkTIsLivwKKigsj8XYlwt/WKi2N4d//uQRCSAAjURNIHpMZBGYiaQPSYyAAABLAAAAAAAACWAAAAApUF/Mg+0aohSIRobBAsMlO//Kk4soosy1JSFRYWaLC4qZBYWFRGZdwqKiwkNBVmoWFSJkWFxX4FFRQWR+LsS4W/rFRb/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////VEFHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAU291bmRib3kuZGUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMjAwNGh0dHA6Ly93d3cuc291bmRib3kuZGUAAAAAAAAAACU=");
				snd.play();
			}
			var Errors = window.Errors;
			var Updated_Errors = 0;
			htmlContent = htmlContent.replace(/<input.*?Refresh Data.*?>/i,"");
			document.documentElement.innerHTML = htmlContent;
			const style = document.createElement('style');
			style.innerHTML = `
				.custom-notification {
					position: fixed;
					bottom: 20px;
					left: 50%;
					transform: translateX(-50%);
					padding: 15px 30px;
					background-color: #323232;
					color: #fff;
					border-radius: 5px;
					box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
					font-size: 16px;
					z-index: 10000;
					opacity: 1;
					transition: opacity 0.5s;
				}
			`;
			document.head.appendChild(style);
			window.showNotification = function(message, duration = 3000) {
				let notification = document.createElement('div');
				notification.className = 'custom-notification';
				notification.textContent = message;
				document.body.appendChild(notification);
				setTimeout(() => {
					notification.style.opacity = '0';
					setTimeout(() => {
						try{
						document.body.removeChild(notification);
						}catch{
						}
					}, 500);
				}, duration);
			};
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
					try{
					document.body.removeChild(overlay);
					}catch{
					}
				}, totalDuration);
			};
            window.getElementByXpath = function(path) {
                    return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
            }

			if (htmlContent.match(/Failure:/g) != null) {
				Updated_Errors = htmlContent.match(/Failure:/g).length;
			}

            const lastAction = window.getElementByXpath('/html/body/table[3]/tbody/tr[2]/td[12]');
            const lastTest = window.getElementByXpath('/html/body/table[3]/tbody/tr[2]/td[4]');
            const SN = window.location.href.match(/target_sn=(\d+)/i);
            let Failures = htmlContent.match(/Failure:.*?($|\n|\r)/gi);

            if (typeof lastAction != "undefined" && lastAction && lastAction.textContent.match(/(exit|reboot)/i) && typeof lastTest != "undefined" && lastTest && (window.lastTest != lastTest.textContent || window.lastAction != lastAction.textContent) && SN.length >= 2) {
                window.lastTest = lastTest.textContent;
                window.lastAction = lastAction.textContent;

                let failString = "";
                if (Failures) {
                  Failures.forEach(function(num,index){
                      if(index < Failures.length && num === Failures[index + 1]){
                          Failures.splice(index,1);
                      }
                  });
                  failString = Failures.join("<br>");
                }


                const messagePayload = {
                        "@type": "MessageCard",
                        "@context": "http://schema.org/extensions",
                        "text": `[${SN[1]}] : ${lastTest.textContent} - ${lastAction.textContent}<br><br>${failString}`};
                GM_xmlhttpRequest({
                    method: "POST",
                    url: "https://ztgroup.webhook.office.com/webhookb2/ac118ee4-10a1-4a48-bf28-6113e5332d1b@456511db-ed57-4e12-aeab-e9fcdcccfca4/IncomingWebhook/b4c67a7ec84447c69240fdcabe03e188/ad96ba98-4259-4834-841a-bc89209cf158",
                    headers: {
                        "Content-Type": "application/json"
                    },
                    data: JSON.stringify(messagePayload),
                    onload: function(response) {
                        console.log('Success:', response.responseText);
                    },
                    onerror: function(response) {
                        console.error('Error:', response.statusText);
                    }
                });
            }

			if (Updated_Errors > Errors) {
				var New_Errors = Updated_Errors - Errors;
				flashScreen();
				beep();
				setTimeout(() => {beep()}, 250);
				setTimeout(() => {beep()}, 250);
				window.Errors = Updated_Errors;
				showNotification("You have " + New_Errors + " new errors.");
			}
			Array.from(document.querySelectorAll("tr")).forEach(a => {
				if (a.children.length >= 13 && parseInt(a.children[13].innerHTML)) {
					if (parseInt(a.children[13].innerHTML) >= 60) {
						a.children[13].innerHTML = "<strong>" + (Math.round(parseInt(a.children[13].innerHTML) / 60).toString()) + " Min</strong>"
					}
				}
			});
		})
		.catch(error => console.error('There was an error fetching the data:', error));
	}, 15000);
})();
