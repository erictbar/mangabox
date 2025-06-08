const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');

let mainWindow;

app.commandLine.appendSwitch('enable-features', 'OverlayScrollbar');

app.on('ready', () => {
	mainWindow = new BrowserWindow({
		width: 1200,
		height: 760,
		center: true,
		autoHideMenuBar: true,
		frame: false,         // Disable the default window frame
		titleBarStyle: 'hidden', // Optional: macOS specific
		trafficLightPosition: { x: -1000, y: 0 }, // ✅ hide traffic lights (move them offscreen)
		titleBarOverlay: false,

		webPreferences: {
			preload: path.join(__dirname, 'package-preload.js'),
			nodeIntegration: false,
			contextIsolation: true,
			allowRunningInsecureContent: true
		},
	});

	mainWindow.loadFile('index.html'); // Replace 'index.html' with your main HTML file name
	mainWindow.webContents.setVisualZoomLevelLimits(1, 5);

	ipcMain.on('window-minimize', () => {
		mainWindow.minimize();
	});

	ipcMain.on('window-maximize', () => {
		if (mainWindow.isMaximized()) {
			mainWindow.unmaximize();
		} else {
			mainWindow.maximize();
		}
	});

	ipcMain.on('window-close', () => {
		mainWindow.close();
	});

	mainWindow.on('enter-full-screen', () => {
		mainWindow.webContents.send('fullscreen-changed', true);
	});

	mainWindow.on('leave-full-screen', () => {
		mainWindow.webContents.send('fullscreen-changed', false);
	});


	mainWindow.on('maximize', () => {
		mainWindow.webContents.send('window-maximized');
	});

	mainWindow.on('unmaximize', () => {
		mainWindow.webContents.send('window-unmaximized');
	});

	ipcMain.handle('get-app-version', () => {
		return app.getVersion(); // This uses the version from package.json
	});
	// Check URL changes and enable zoom conditionally
	/* 
	 mainWindow.webContents.on('did-navigate', (_, url) => {
	  if (url.includes('bookread')) {
		 // ✅ Enable pinch-to-zoom only when URL contains "reader.html"
		 mainWindow.webContents.setVisualZoomLevelLimits(1, 5);
	  } else {
		 // ❌ Disable pinch-to-zoom for other pages
		 mainWindow.webContents.setVisualZoomLevelLimits(1, 1);
	  }
	});
	*/
});

app.on('window-all-closed', () => {
	app.quit();
});
function initLibraryScroll() {
  const librariesList = document.getElementById('librariesList');
  const scrollLeftBtn = document.getElementById('scrollLeftBtn');
  const scrollRightBtn = document.getElementById('scrollRightBtn');
  const stickyContainer = document.getElementById('stickyContainer');
  const librariesRightBlock = document.getElementById('librariesRightBlock');
  
  if (!librariesList) return;
  
  // Calculate minimum libraries to display (at least Dashboard + 3 libraries when possible)
  const minVisibleLibraries = 4;
  
  // Create drag scrolling
  let isDown = false;
  let startX;
  let scrollLeft;
  
  librariesList.addEventListener('mousedown', (e) => {
    isDown = true;
    librariesList.classList.add('grabbing');
    startX = e.pageX - librariesList.offsetLeft;
    scrollLeft = librariesList.scrollLeft;
  });
  
  librariesList.addEventListener('touchstart', (e) => {
    isDown = true;
    librariesList.classList.add('grabbing');
    startX = e.touches[0].pageX - librariesList.offsetLeft;
    scrollLeft = librariesList.scrollLeft;
  });
  
  librariesList.addEventListener('mouseleave', () => {
    isDown = false;
    librariesList.classList.remove('grabbing');
  });
  
  librariesList.addEventListener('mouseup', () => {
    isDown = false;
    librariesList.classList.remove('grabbing');
  });
  
  librariesList.addEventListener('touchend', () => {
    isDown = false;
    librariesList.classList.remove('grabbing');
  });
  
  librariesList.addEventListener('mousemove', (e) => {
    if (!isDown) return;
    e.preventDefault();
    const x = e.pageX - librariesList.offsetLeft;
    const walk = (x - startX) * 1.5;
    librariesList.scrollLeft = scrollLeft - walk;
  });
  
  librariesList.addEventListener('touchmove', (e) => {
    if (!isDown) return;
    const x = e.touches[0].pageX - librariesList.offsetLeft;
    const walk = (x - startX) * 1.5;
    librariesList.scrollLeft = scrollLeft - walk;
  });
  
  // Function to adjust visible libraries based on screen width
  function adjustVisibleLibraries() {
    const containerWidth = stickyContainer.offsetWidth;
    const rightBlockWidth = librariesRightBlock ? librariesRightBlock.offsetWidth : 0;
    const availableWidth = containerWidth - rightBlockWidth - 20; // 20px buffer
    
    const libraryItems = Array.from(librariesList.querySelectorAll('.library-item'));
    
    // Make all items visible by default
    libraryItems.forEach(item => {
      item.style.display = 'flex';
    });
    
    // Calculate button size - use a consistent size for non-highlighted buttons
    const buttonSize = 48; // Default button size in px
    const buttonMargin = 6; // Default margin in px
    
    // Calculate how many libraries we can fit
    let totalWidth = 0;
    let visibleCount = 0;
    let highlightedWidth = 0;
    
    // Find highlighted item if any
    const highlightedItem = librariesList.querySelector('.library-item.highlighted');
    
    // First add the highlight item's width if it exists
    if (highlightedItem) {
      highlightedWidth = highlightedItem.offsetWidth;
      totalWidth += highlightedWidth;
      visibleCount = 1;
    }
    
    // Then add non-highlighted items until we fill the space
    for (let i = 0; i < libraryItems.length; i++) {
      if (libraryItems[i] === highlightedItem) continue;
      
      const itemWidth = buttonSize + buttonMargin * 2;
      
      if (totalWidth + itemWidth <= availableWidth) {
        totalWidth += itemWidth;
        visibleCount++;
      } else {
        break;
      }
    }
    
    // Always ensure we have at least the minimum number of libraries visible if possible
    visibleCount = Math.max(visibleCount, Math.min(minVisibleLibraries, libraryItems.length));
    
    // Show at least Dashboard + 3 libraries
    if (visibleCount < libraryItems.length) {
      // Always keep Dashboard visible (first item)
      libraryItems[0].style.display = 'flex';
      
      // If there's a highlighted item, keep it visible
      if (highlightedItem) {
        highlightedItem.style.display = 'flex';
      }
      
      // Display scroll buttons if not all libraries fit
      if (scrollLeftBtn) scrollLeftBtn.style.display = 'flex';
      if (scrollRightBtn) scrollRightBtn.style.display = 'flex';
    } else {
      // Hide scroll buttons if all fit
      if (scrollLeftBtn) scrollLeftBtn.style.display = 'none';
      if (scrollRightBtn) scrollRightBtn.style.display = 'none';
    }
  }
  
  // Add click handlers for scroll buttons
  if (scrollLeftBtn) {
    scrollLeftBtn.addEventListener('click', () => {
      librariesList.scrollBy({
        left: -200,
        behavior: 'smooth'
      });
    });
  }
  
  if (scrollRightBtn) {
    scrollRightBtn.addEventListener('click', () => {
      librariesList.scrollBy({
        left: 200,
        behavior: 'smooth'
      });
    });
  }
  
  // Run adjustment when window is resized
  window.addEventListener('resize', adjustVisibleLibraries);
  
  // Initial adjustment
  setTimeout(adjustVisibleLibraries, 100);
}