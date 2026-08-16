import { api, signIn } from './api.js';
import { requireConfiguration, setBusy, showMessage } from './ui.js';

if (requireConfiguration()) {
  document.querySelector('#login-form').addEventListener('submit', async event => {
    event.preventDefault();
    const button = event.currentTarget.querySelector('button');
    setBusy(button, true, 'Signing in…');
    try {
      const session = await signIn(document.querySelector('#email').value.trim(), document.querySelector('#password').value, document.querySelector('#device').value.trim());
      const access = await api.myAccess();
      const role = access.role;
      window.location.replace(role === 'driver' ? 'delivery.html' : ['owner', 'admin', 'manager'].includes(role) ? 'admin.html' : 'staff.html');
    } catch (error) { showMessage('#message', error.message); }
    finally { setBusy(button, false); }
  });
}
