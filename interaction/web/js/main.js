import { createOptions } from "./createOptions.js";
import { fetchNui } from "./fetchNui.js";
import { onSelect } from "./controls.js";
import { setCurrentIndex, resetHold, setDefaultColor } from "./controls.js";

const optionsWrapper = document.getElementById("options-wrapper");
const container = document.getElementById("container");
const body = document.body;
body.style.visibility = "visible";

// Initially hide options, show only E button
container.classList.remove("expanded");

// Track if options are open
let optionsOpen = false;

function Interact() {
  if (!optionsOpen) {
    // First E press: open options
    container.classList.add("expanded");
    optionsOpen = true;
  } else {
    // Second E press: select highlighted option
    const highlightedOption = optionsWrapper.querySelector(
      ".option-container.highlighted"
    );
    if (highlightedOption) {
      // Add selection feedback animation
      highlightedOption.classList.add("selected");

      // Remove the animation class after it completes
      setTimeout(() => {
        highlightedOption.classList.remove("selected");
      }, 600);
    }

    onSelect();
    // Close options after selection animation completes
    setTimeout(() => {
      container.classList.remove("expanded");
      optionsOpen = false;
    }, 600);
  }
}

function CloseInteract() {
  container.classList.remove("expanded");
  optionsOpen = false;
}

// document.addEventListener("keydown", (event) => {
//   if (event.key === "e" || event.key === "E") {
//     Interact();
//   }
// });

// Mouse wheel navigation when options are open
// document.addEventListener("wheel", (event) => {
//   if (optionsOpen) {
//     const options = optionsWrapper.querySelectorAll(".option-container");
//     if (options.length === 0) return;

//     let currentIndex = 0;
//     options.forEach((option, index) => {
//       if (option.classList.contains("highlighted")) {
//         currentIndex = index;
//       }
//     });

//     if (event.deltaY > 0) {
//       // Scroll down: increment index
//       currentIndex = (currentIndex + 1) % options.length;
//     } else {
//       // Scroll up: decrement index with wrap-around
//       currentIndex = (currentIndex - 1 + options.length) % options.length;
//     }

//     // Update highlight
//     options.forEach(option => option.classList.remove("highlighted"));
//     options[currentIndex].classList.add("highlighted");
//   }
// });

window.addEventListener("message", (event) => {
  switch (event.data.action) {
    case "visible": {
      // body.style.visibility = event.data.value ? "visible" : "hidden";
      break;
    }

    case "setOptions": {
      optionsWrapper.innerHTML = "";

      if (event.data.value.options) {
        for (const type in event.data.value.options) {
          event.data.value.options[type].forEach((data, id) => {
            createOptions(type, data, id + 1);
          });
        }
        if (event.data.value.resetIndex) {
          setCurrentIndex(0);
        }
      }
      break;
    }

    case "interact": {
      Interact();
      // This is now handled by the keydown event listener
      break;
    }

    case "release": {
      CloseInteract();
      break;
    }

    case "setColor": {
      console.log("setColor", event.data.value);
      const c = event.data.value;
      const color = `rgb(${c[0]}, ${c[1]}, ${c[2]}, ${c[3] / 255})`;
      setDefaultColor(color);
      body.style.setProperty("--theme-color", color);
      console.log("Renk set", color);
      break;
    }

    case "setCooldown": {
      body.style.opacity = event.data.value ? "0.3" : "1";
      const interactKey = document.getElementById("interact-key");

      interactKey.innerHTML = event.data.value
        ? `<i class="fa-solid fa-spinner spinner-rotate"></i>`
        : "E";

      break;
    }
  }
});

window.addEventListener("load", async (event) => {
  await fetchNui("load", {});
});
