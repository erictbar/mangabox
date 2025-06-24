//MB Manage Electron titlebar

const isElectronApp = !!window.electronAPI;

// DOM element references
const dragbarMinBtn = document.getElementById('minBtn');
const dragbarMaxBtn = document.getElementById('maxBtn');
const dragbarCloseBtn = document.getElementById('closeBtn');
const dragbarAppTitle = document.getElementById('appName');
const fullscreenLabel = document.getElementById('fullscreenLabel');
const debuggerObj = document.getElementById('debuggerObj');
const colorSwatchBar = document.getElementById('colorSwatchBar');
const authContainer = document.getElementById('authContainer');
const stickyContainer = document.getElementById('stickyContainer');

function enableDragbar(enabled) {
	if (!enabled) {
		document.documentElement.style.setProperty('--mb-drag-bar-height', '0px');
		document.getElementById('dragbar').style.display = 'none';
	} else {
		document.documentElement.style.setProperty('--mb-drag-bar-height', '22px');
		document.getElementById('dragbar').style.display = '';
	}
}

if (isElectronApp) {
	dragbarMinBtn.addEventListener('click', () => {
		window.electronAPI.minimize();
	});

	dragbarMaxBtn.addEventListener('click', () => {
		window.electronAPI.maximize();
	});

	dragbarCloseBtn.addEventListener('click', () => {
		window.electronAPI.close();
	});

	window.electronAPI.onFullscreenChange((isFullscreen) => {
		enableDragbar(!isFullscreen);
	});

	window.electronAPI.onMaximize(() => {
		dragbarMaxBtn.classList.remove('fa-window-maximize');
		dragbarMaxBtn.classList.add('fa-window-restore');
	});

	window.electronAPI.onUnmaximize(() => {
		dragbarMaxBtn.classList.remove('fa-window-restore');
		dragbarMaxBtn.classList.add('fa-window-maximize');
	});

	window.electronAPI.getAppVersion().then(version => {
		dragbarAppTitle.textContent = 'MangaBox v' + version;
	});
}

// Hide dragbar in PWA mode
(function () {
	enableDragbar(isElectronApp);
})();


//MB General Functions 
function debugPrint(text) {
	debuggerObj.innerText = debuggerObj.innerText + text;
}

function addItem(itemkind, properties) {
	const { style, ...rest } = properties;
	const element = Object.assign(document.createElement(itemkind), rest);
	if (style) Object.assign(element.style, style);
	return element;
}

function getScreenAR() {
	return (window.innerWidth / window.innerHeight);
}

function toggleFullscreen() {
	if (!document.fullscreenElement) {
		document.documentElement.requestFullscreen();
	} else {
		document.exitFullscreen();
	}
}

document.addEventListener('fullscreenchange', updateFullscreenLabel);

function updateFullscreenLabel() {
	fullscreenLabel.classList.remove('fa-expand', 'fa-compress');
	if (document.fullscreenElement) {
		fullscreenLabel.classList.add('fa-compress');
	} else {
		fullscreenLabel.classList.add('fa-expand');
	}
}

//MB Main Variable Setup 

// Main MangaBox data structure, for variables that are common to the whole app
let mb = {

	authHeader: localStorage.getItem('mbAuthHeader'),
	baseUrl: localStorage.getItem('mbBaseUrl'),
	rememberMe: localStorage.getItem('mbRememberMe'),

	basePath: '', //'/mangabox/'
	darkTheme: false,

	// Scaling of selected item control
	currentlyScaled: null,

	// Current book references for book details
	currentBook: null,
	prevBook: null,
	nextBook: null,

	// Screen aspect ratio functions
	screenAR: getScreenAR(),
	readerMaxRatio: 1,
	readerHorizontal: true,
	resizeTimeout: null,

	// Filter table placeholders
	filterTable: null,
	filterButtons: null,
	filterSizer: null,

	libraryMenuButtons: {},

	libSizer: {}, // Used to calculate libraries button size
	dashboardBin: "",
	/*
		When an item from a bin is opened, the mb.dashboardBin is set, so when the dashboard is reloaded
		it reads this variable, if it is not "" the focus is shifted to the bin, and the variable is cleared.
		In this way subsequent clicks on dashboard button will load the top position.
		This variable is cleared whenever a new "Navigate To" is called that is not to dashboard
	*/

	// Discord RPC integration
	discordRPC: null,

	// Media cache for image optimization
	mediaCache: new Map(),

	prefersDarkMode: window.matchMedia('(prefers-color-scheme: dark)'),

	discordRPC: {
		enabled: false,
		activityTimeout: null,
		lastBookId: null
	}

}

// Initialize Discord RPC
try {
	if (typeof DiscordRPC !== 'undefined') {
		mb.discordRPC = new DiscordRPC();
		console.log('Discord RPC initialized');
	} else {
		console.log('Discord RPC class not available');
		mb.discordRPC = { enabled: false, isEnabled: false };
	}
} catch (error) {
	console.warn('Failed to initialize Discord RPC:', error);
	mb.discordRPC = { enabled: false, isEnabled: false };
}

//TODO: make this a function that repsonds to theme changes and create/colorizes the blocks? and maybe use it at bootsequence
const colorValues = getComputedStyle(document.documentElement)
	.getPropertyValue('--mb-swatches-hi')
	.match(/hsl\([^)]*\)/g);

colorValues.forEach((value, index) => {
	const appleColor = [0, 1, 1, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1];
	const colorSwatch = addItem('span', {
		className: 'color-swatch',
		innerHTML: appleColor[index] == 1 ? '<i class="fa-brands fa-apple"></i>' : '',
		style: {
			backgroundColor: value,
		},
	});
	colorSwatch.addEventListener('click', () => {
		event.stopPropagation();
		mb.accentColor = index;
		applyAccent();
	});
	colorSwatchBar.append(colorSwatch);
});

//MB API Call Function 
async function callAPI(API_url, method = 'GET', body = null, returnval = true) {
	try {
		const response = await fetch(`${mb.baseUrl}${API_url}`, {
			method: method,
			headers: {
				'Authorization': mb.authHeader,
				'Content-Type': 'application/json',
				'skip_zrok_interstitial': '1' // Add header to skip interstitial
			},
			body: body
		});

		if (!response.ok) throw new Error(`Network response was not ok: ${response.statusText}`);

		if (returnval) {
			const output = await response.json();
			return output;
		}
	} catch (error) {
		console.error('Fetch libraries error:', error);
	}
}

async function getUserSettings() {
	const settings = await callAPI('/api/v1/client-settings/user/list', 'GET');
	const mangaboxFlat = Object.fromEntries(
		Object.entries(settings)
			.filter(([key]) => key.startsWith("mangabox"))
			.map(([key, obj]) => [key, obj.value])
	);
	return mangaboxFlat
}

async function setUserSettings(key, value) {
	const payload = {
		[key]: { value: value },
	};
	await callAPI('/api/v1/client-settings/user', 'PATCH', JSON.stringify(payload), false);
}

//MB Theme Management 

function warmth(hue) {
	const warmth = (Math.cos((hue - 50) * Math.PI / 180) + 1) / 2;
	return warmth;
}

function applyAccent() {
	const swatches = mb.darkTheme ? mb.swatchesLo : mb.swatchesHi;

	['--mb-h', '--mb-s', '--mb-l'].forEach((varName, index) => {
		document.documentElement.style.setProperty(varName, swatches[mb.accentColor][index]);
	});
	document.documentElement.style.setProperty('--mb-h-deg', swatches[mb.accentColor][0] + 'deg');

	document.documentElement.style.setProperty('--mb-gradient-1', Number(swatches[mb.accentColor][0]));
	document.documentElement.style.setProperty('--mb-gradient-2', Number(swatches[mb.accentColor][0]) - 10);

	setUserSettings("mangabox.ui.accentcolor", mb.accentColor);
}

function swapThemeClass(classSelector, lightClass, darkClass, toDark) {
	Array.from(document.getElementsByClassName(classSelector)).forEach((item) => {
		if (!item.classList.contains('no-theme-icon')) {
			item.classList.remove(toDark ? lightClass : darkClass);
			item.classList.add(toDark ? darkClass : lightClass);
		}
	});
}

function updatePWABar(color = null) {
	document.querySelector('meta[name="theme-color"]')
		.setAttribute('content', color ?? (mb.darkTheme ? '#353535' : '#ffffff'));
}

function changeTheme() {
	let toDark = false;

	if (mb.themePrefs != 2) {
		toDark = (mb.themePrefs == 1)
	} else {
		toDark = mb.prefersDarkMode.matches ? true : false
	}

	// Set css theme to dark or light
	document.documentElement.setAttribute('data-theme', toDark ? 'dark' : 'light');

	if (mb.themeControl) {
		mb.themeControl.forEach(item => {
			const themeLabel = document.getElementById('themeLabel');
			if (themeLabel) themeLabel.classList.remove(item.icon);
		});

		const themeLabel = document.getElementById('themeLabel');
		if (themeLabel) {
			themeLabel.classList.add(mb.themeControl[mb.themePrefs].icon);
			themeLabel.title = mb.themeControl[mb.themePrefs].label;
		}
	}

	// Change fa icons for light or dark theme
	swapThemeClass('fa-file', 'fa-regular', 'fa-solid', toDark);
	swapThemeClass('fa-calendar', 'fa-regular', 'fa-solid', toDark);
	swapThemeClass('fa-clock', 'fa-regular', 'fa-solid', toDark);

	// Save theme setting in local storage
	setUserSettings('mangabox.ui.themeprefs', mb.themePrefs);

	mb.darkTheme = toDark;

	//Theme based top bar
	updatePWABar();

	applyAccent();
}

// Show/Hide section functions
function sectionHide(item) {
	if (item) item.classList.add('hidden');
}
function sectionShow(item) {
	if (item) item.classList.remove('hidden');
}
function sectionToggle(item) {
	if (item) item.classList.toggle('hidden');
}
function isSectionHidden(item) {
	return item ? item.classList.contains('hidden') : true;
}

// Navigation function
function navigateTo(hash) {
	console.log('Navigating to:', hash);
	window.location.hash = hash;
	
	// Show appropriate content based on hash
	if (hash === '#dashboard') {
		showDashboard();
	}
}

// Show dashboard content
function showDashboard() {
	console.log('Showing dashboard');
	
	// Hide all sections first
	const sections = document.querySelectorAll('.section');
	sections.forEach(section => sectionHide(section));
	
	// Show main container content
	const mainContainer = document.getElementById('mainContainer');
	if (mainContainer) {
		mainContainer.style.display = 'block';
		console.log('Main container shown');
	}
	
	// Ensure the main UI is visible
	const mainUI = document.getElementById('mainUI');
	if (mainUI) {
		mainUI.style.display = 'block';
		console.log('Main UI container shown');
	}
	
	// You can add more dashboard-specific content here
}

// Fetch libraries function
async function fetchLibraries() {
	try {
		console.log('Fetching libraries...');
		const libraries = await callAPI('/api/v1/libraries');
		libraries.sort((a, b) => a.name.localeCompare(b.name));
		console.log('Libraries loaded:', libraries);
		
		// Display libraries in the UI
		displayLibraries(libraries);
	} catch (error) {
		console.error('Error fetching libraries:', error);
	}
}

// Display libraries in the UI
function displayLibraries(libraries) {
	console.log('Displaying libraries:', libraries);
	const librariesList = document.getElementById('librariesList');
	if (!librariesList) {
		console.error('librariesList element not found');
		return;
	}
	
	console.log('Libraries list element found, clearing content');
	// Clear existing content
	librariesList.innerHTML = '';
	
	if (!libraries || libraries.length === 0) {
		console.log('No libraries to display');
		librariesList.innerHTML = '<li style="color: white; padding: 10px;">No libraries found</li>';
		return;
	}
	
	// Add each library as a list item
	libraries.forEach((library, index) => {
		console.log(`Adding library ${index + 1}:`, library.name);
		const listItem = document.createElement('li');
		listItem.className = 'library-item';
		listItem.style.color = 'white'; // Force white text for visibility
		listItem.innerHTML = `
			<div class="button-wrapper">
				<span class="fa-solid fa-book glyph-dark"></span>
				<span class="library-name">${library.name}</span>
			</div>
		`;
		listItem.addEventListener('click', () => {
			console.log('Library clicked:', library.name);
			// Add library navigation logic here
		});
		librariesList.appendChild(listItem);
	});
	
	console.log(`Successfully displayed ${libraries.length} libraries`);
	
	// Update the temp content to show library count
	const tempContent = document.getElementById('tempVisibleContent');
	if (tempContent) {
		tempContent.innerHTML = `
			<h3>MangaBox - Main UI Loaded</h3>
			<p>✅ Authentication successful</p>
			<p>✅ Main UI initialized</p>
			<p>✅ Libraries loaded: ${libraries.length}</p>
		`;
	}
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', async function() {
	try {
		const userSettings = await getUserSettings();
		mb.accentColor = Number(userSettings['mangabox.ui.accentcolor'] ?? 0);
		mb.themePrefs = Number(userSettings['mangabox.ui.themeprefs'] ?? 0);
		mb.readerThemePrefs = Number(userSettings['mangabox.ui.readerthemeprefs'] ?? 0);
		mb.libraryFilters = JSON.parse(userSettings['mangabox.ui.libraryfilters'] || '{}');
		mb.libraryIcons = JSON.parse(userSettings['mangabox.ui.libraryicons'] || '{}');
		
		// Initialize the app
		bootSequence();
	} catch (error) {
		console.error('Error loading user settings:', error);
		// Continue with defaults
		bootSequence();
	}
});

function bootSequence() {
	console.log('Boot sequence starting');
	// Set up initial theme and layout
	changeTheme();
	applyAccent();
	
	console.log('Auth check:', mb.authHeader, mb.baseUrl);
	
	// Check authentication
	if (mb.authHeader && mb.baseUrl) {
		// User is logged in, load main interface
		console.log('User authenticated, showing main UI');
		sectionHide(authContainer);
		sectionShow(stickyContainer);
		
		// Add some debug info to see if sticky container is visible
		if (stickyContainer) {
			console.log('Sticky container classes:', stickyContainer.className);
			console.log('Sticky container display:', getComputedStyle(stickyContainer).display);
		}
		
		fetchLibraries();
		navigateTo('#dashboard');
		
		// Add temporary visible content for testing
		const tempContent = document.createElement('div');
		tempContent.id = 'tempVisibleContent';
		tempContent.style.cssText = `
			position: fixed;
			top: 100px;
			left: 20px;
			background: #333;
			color: white;
			padding: 20px;
			border-radius: 8px;
			z-index: 1000;
			font-family: Arial, sans-serif;
		`;
		tempContent.innerHTML = `
			<h3>MangaBox - Main UI Loaded</h3>
			<p>✅ Authentication successful</p>
			<p>✅ Main UI initialized</p>
			<p>Libraries loading...</p>
		`;
		document.body.appendChild(tempContent);
		
		// Remove after 5 seconds
		setTimeout(() => {
			if (tempContent.parentNode) {
				tempContent.parentNode.removeChild(tempContent);
			}
		}, 5000);
	} else {
		// Show login form
		console.log('User not authenticated, showing login form');
		sectionShow(authContainer);
		sectionHide(stickyContainer);
	}
}

// Add Discord RPC update function
async function updateDiscordActivity(bookData = null, currentPage = null, totalPages = null) {
	if (!mb.discordRPC || !mb.discordRPC.isEnabled) return;
	
	try {
		if (!bookData) {
			await mb.discordRPC.clearActivity();
			return;
		}
		
		const progress = totalPages ? Math.round((currentPage / totalPages) * 100) : 0;
		await mb.discordRPC.setActivity({
			details: `Reading ${bookData.seriesTitle}`,
			state: `Vol.${bookData.metadata.number} - ${progress}% (${currentPage}/${totalPages})`,
			startTimestamp: Date.now(),
			largeImageKey: 'manga_icon',
			largeImageText: bookData.metadata.title,
			smallImageKey: 'reading_icon',
			smallImageText: 'Reading manga'
		});
	} catch (error) {
		console.error("Failed to update Discord activity:", error);
	}
}

// Theme control setup
mb.themeControl = [
	{ icon: 'fa-circle-half-stroke', label: 'Auto' },
	{ icon: 'fa-sun', label: 'Light' },
	{ icon: 'fa-moon', label: 'Dark' }
];

// Initialize color swatches from CSS variables
mb.swatchesHi = [];
mb.swatchesLo = [];

// Extract color values from CSS and populate swatches
try {
	const hiColors = getComputedStyle(document.documentElement)
		.getPropertyValue('--mb-swatches-hi')
		.match(/hsl\([^)]*\)/g);
	const loColors = getComputedStyle(document.documentElement)
		.getPropertyValue('--mb-swatches-lo')
		.match(/hsl\([^)]*\)/g);

	if (hiColors) {
		mb.swatchesHi = hiColors.map(color => {
			const match = color.match(/hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)/);
			return match ? [match[1], match[2], match[3]] : [0, 0, 50];
		});
	}

	if (loColors) {
		mb.swatchesLo = loColors.map(color => {
			const match = color.match(/hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)/);
			return match ? [match[1], match[2], match[3]] : [0, 0, 50];
		});
	}
} catch (error) {
	console.warn('Could not extract color swatches from CSS:', error);
	// Fallback color swatches
	mb.swatchesHi = [[0, 0, 50], [210, 100, 60], [120, 100, 40]];
	mb.swatchesLo = [[0, 0, 30], [210, 100, 40], [120, 100, 25]];
}

// Initialize Discord RPC

// Add event listeners for UI elements
document.addEventListener('DOMContentLoaded', function() {
	// Login button event listener
	const loginBtn = document.getElementById('loginBtn');
	if (loginBtn) {
		loginBtn.addEventListener('click', function() {
			login(); // Call the login function from auth.js
		});
	}

	// Enter key support for login form
	const loginInputs = document.querySelectorAll('#authContainer input');
	loginInputs.forEach(input => {
		input.addEventListener('keypress', function(event) {
			if (event.key === 'Enter') {
				login();
			}
		});
	});

	// Fullscreen toggle
	const fullscreenChanger = document.getElementById('fullscreenChanger');
	if (fullscreenChanger) {
		fullscreenChanger.addEventListener('click', toggleFullscreen);
	}

	// Theme changer
	const themeChanger = document.getElementById('themeChanger');
	if (themeChanger) {
		themeChanger.addEventListener('click', function() {
			mb.themePrefs = (mb.themePrefs + 1) % mb.themeControl.length;
			changeTheme();
		});
	}

	// Color changer
	const colorChanger = document.getElementById('colorChanger');
	if (colorChanger) {
		colorChanger.addEventListener('click', function() {
			sectionToggle(colorSwatchBar);
		});
	}

	// Logout button
	const logOut = document.getElementById('logOut');
	if (logOut) {
		logOut.addEventListener('click', function() {
			localStorage.removeItem('mbAuthHeader');
			localStorage.removeItem('mbBaseUrl');
			location.reload();
		});
	}
});
