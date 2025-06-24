// script.js

// Show the login dialog if no auth header or base URL is available
if (!localStorage.getItem('mbAuthHeader') || !localStorage.getItem('mbBaseUrl')) {
	console.log('No auth header or base URL found, showing login dialog.');
	if (localStorage.getItem('mbBaseUrl')) {
		console.log('Prefilling serverUrl with', localStorage.getItem('mbBaseUrl'));
		document.getElementById('serverUrl').value = localStorage.getItem('mbBaseUrl');
	}
	showLoginDialog();
} else {
	console.log('Auth header and base URL found:', localStorage.getItem('mbAuthHeader'), localStorage.getItem('mbBaseUrl'));
}

function login() {
	let mbBaseUrl = document.getElementById('serverUrl').value;
	const username = document.getElementById('username').value;
	const password = document.getElementById('password').value;
	const rememberMe = document.getElementById('rememberMe').checked;

	if (!/^https?:\/\//i.test(mbBaseUrl)) {
		// Add http:// if no protocol is present
		mbBaseUrl = 'https://' + mbBaseUrl;
	}

	mbBaseUrl = mbBaseUrl.replace(/\/$/, '');

	const mbAuthHeader = 'Basic ' + btoa(`${username}:${password}`);

	// Parse origin and path for subfolder support
	const urlObj = new URL(mbBaseUrl);
	const origin = urlObj.origin;
	const basePath = urlObj.pathname.replace(/\/$/, '');

	// Test the auth header and base URL with a simple API call to validate credentials
	fetch(`${mbBaseUrl}/api/v1/login/set-cookie`, {
		method: 'GET',
		headers: { 
			'Authorization': mbAuthHeader,
			'skip_zrok_interstitial': '1'
		 }
	})
		.then(response => {
			console.log('Login response:', response);
			if (response.ok) {
				localStorage.setItem('mbRememberMe', rememberMe);
				localStorage.setItem('mbAuthHeader', mbAuthHeader); // Save auth header
				localStorage.setItem('mbBaseUrl', origin);      // Save only the origin
				localStorage.setItem('mbBasePath', basePath);   // Save only the path
				console.log('Login successful, hiding dialog and reloading.');
				hideLoginDialog();
				console.log('Dialog hidden, reloading page...');
				location.reload(true);
				//fetchLibraries(); // Fetch libraries after successful login
			} else {
				console.log('Login failed, showing error.');
				localStorage.setItem('mbBaseUrl', origin);      // Save only the origin
				localStorage.setItem('mbBasePath', basePath);   // Save only the path
				document.getElementById('loginError').classList.remove('hidden'); // Show error message
			}
		})
		.catch(error => {
			console.error('Login error:', error);
			document.getElementById('loginError').classList.remove('hidden');
		});
}

function showLoginDialog() {
	document.getElementById('authContainer').classList.remove('hidden');
}

function hideLoginDialog() {
	document.getElementById('authContainer').classList.add('hidden');
}
