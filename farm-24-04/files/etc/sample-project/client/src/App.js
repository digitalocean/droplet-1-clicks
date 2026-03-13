import logo from './logo.png';
import './App.css';

function App() {
	return (
		<div className="App">
			<header className="App-header">
				<img src={logo} className="App-logo" alt="logo" />
				<p>
					Welcome to your FARM droplet!
				</p>
				<a
					className="App-link"
					href="https://marketplace.digitalocean.com/apps/farm#getting-started"
					target="_blank"
					rel="noopener noreferrer"
				>
					Getting started
				</a>
			</header>
		</div>
	);
}

export default App;
