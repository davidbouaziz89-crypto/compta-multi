-- =====================================================================
-- Auto-création du profil applicatif à chaque nouvel utilisateur auth.
-- Bootstrap : l'email de David est marqué admin automatiquement.
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  insert into public.app_users(user_id, email, is_admin)
  values (new.id, new.email, new.email = 'davidbouaziz89@gmail.com')
  on conflict (user_id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
