-- push_log.sender had no foreign key, so a deleted account stayed behind as
-- the sender of every push it caused. It now goes with the account, like the
-- recipient already did. (It is part of the primary key, so it cannot be set
-- to null instead.)

delete from public.push_log l
where not exists (select 1 from auth.users u where u.id = l.sender);

alter table public.push_log
  add constraint push_log_sender_fkey
  foreign key (sender) references auth.users (id) on delete cascade;

create index push_log_sender_idx on public.push_log (sender);
