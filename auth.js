// script.js

// Wait for DOM to be ready before checking authentication
document.addEventListener('DOMContentLoaded', function() {
	console.log('Auth script loaded');
	
	// Show the login dialog if no auth header or base URL is available
	if (!localStorage.getItem('mbAuthHeader') || !localStorage.getItem('mbBaseUrl')) {
		console.log('No auth found, showing login dialog');
		if (localStorage.getItem('mbBaseUrl')) {
			const serverUrlField = document.getElementById('serverUrl');
			if (serverUrlField) {
				serverUrlField.value = localStorage.getItem('mbBaseUrl');
			}
		}
		showLoginDialog();
	} else {
		console.log('Auth found, hiding login dialog');
		hideLoginDialog();
	}
});

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

	// Test the auth header and base URL with a simple API call to validate credentials
	fetch(`${mbBaseUrl}/api/v1/login/set-cookie`, {
		method: 'GET',
		headers: { 
			'Authorization': mbAuthHeader,
			'skip_zrok_interstitial': '1'
		 }
	})
		.then(response => {
			console.log(response);
			if (response.ok) {
				localStorage.setItem('mbRememberMe', rememberMe);
				localStorage.setItem('mbAuthHeader', mbAuthHeader); // Save auth header
				localStorage.setItem('mbBaseUrl', mbBaseUrl);       // Save base URL
				hideLoginDialog();
				location.reload(true);
				//fetchLibraries(); // Fetch libraries after successful login
			} else {
				localStorage.setItem('mbBaseUrl', mbBaseUrl);       // Save base URL
				document.getElementById('loginError').classList.remove('hidden'); // Show error message
			}
		})
		.catch(error => {
			console.error('Login error:', error);
			document.getElementById('loginError').classList.remove('hidden');
		});
}

function showLoginDialog() {
	console.log('Showing login dialog');
	const authContainer = document.getElementById('authContainer');
	if (authContainer) {
		authContainer.classList.remove('hidden');
		console.log('Login dialog shown');
	} else {
		console.error('authContainer element not found');
	}
}

function hideLoginDialog() {
	console.log('Hiding login dialog');
	const authContainer = document.getElementById('authContainer');
	if (authContainer) {
		authContainer.classList.add('hidden');
		console.log('Login dialog hidden');
	} else {
		console.error('authContainer element not found');
	}
}
