import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Menu } from 'lucide-react';
import { api } from './api/client';
import { useStore } from './store';
import { LoginPage } from './components/auth/LoginPage';
import { RegisterPage } from './components/auth/RegisterPage';
import { NotebookSidebar } from './components/notebooks/NotebookSidebar';
import { NoteTimeline } from './components/notes/NoteTimeline';
import './App.css';

// AuthInitializer renders unconditionally to ensure auth state is loaded
// before ProtectedRoute evaluates, preventing infinite loading state
function AuthInitializer({ children }: { children: React.ReactNode }) {
  const { setUser, setLoading, fetchTags } = useStore();

  useEffect(() => {
    const loadUser = async () => {
      if (api.isAuthenticated()) {
        try {
          const user = await api.getMe();
          setUser(user);
          await fetchTags();
        } catch {
          api.clearTokens();
          setUser(null);
        }
      }
      setLoading(false);
    };
    loadUser();
  }, [setUser, setLoading, fetchTags]);

  return <>{children}</>;
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated, isLoading } = useStore();

  if (isLoading) {
    return <div className="loading">Loading...</div>;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <>{children}</>;
}

function AppLayout() {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <div className="app-layout">
      <NotebookSidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      {sidebarOpen && <div className="sidebar-overlay" onClick={() => setSidebarOpen(false)} />}
      <main className="main-content">
        <button className="mobile-menu-btn" onClick={() => setSidebarOpen(true)}>
          <Menu size={24} />
        </button>
        <NoteTimeline />
      </main>
    </div>
  );
}

function App() {
  return (
    <BrowserRouter>
      <AuthInitializer>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <AppLayout />
              </ProtectedRoute>
            }
          />
        </Routes>
      </AuthInitializer>
    </BrowserRouter>
  );
}

export default App;
