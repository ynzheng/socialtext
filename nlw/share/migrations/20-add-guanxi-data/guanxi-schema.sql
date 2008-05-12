
CREATE TABLE event (
        id INTEGER NOT NULL, 
        timestamp TIMESTAMP WITH time zone, 
        actor_id INTEGER, 
        action TEXT, 
        object TEXT, 
        context TEXT, 
        PRIMARY KEY (id),
         CONSTRAINT event_actor_id_fk FOREIGN KEY(actor_id) REFERENCES "UserId" (system_unique_id)
);
CREATE INDEX ix_event_actor_id ON event (actor_id);

CREATE SEQUENCE event_id_seq;

CREATE TABLE person (
        id INTEGER,
        name TEXT, 
        photo TEXT, 
        small_photo TEXT, 
        first_name TEXT, 
        middle_name TEXT,
        last_name TEXT, 
        position TEXT, 
        location TEXT, 
        email TEXT, 
        work_phone TEXT, 
        mobile_phone TEXT, 
        home_phone TEXT, 
        aol_sn TEXT, 
        yahoo_sn TEXT, 
        gtalk_sn TEXT,
        skype_sn TEXT, 
        sametime_sn TEXT, 
        twitter_sn TEXT, 
        blog TEXT, 
        personal_url TEXT,
        linkedin_url TEXT, 
        facebook_url TEXT, 
        company TEXT, 
        supervisor_id INTEGER, 
        assistant_id INTEGER, 
        PRIMARY KEY (id), 
         CONSTRAINT person_id_fk FOREIGN KEY(id) REFERENCES "UserId" (system_unique_id), 
         CONSTRAINT person_supervisor_id_fk FOREIGN KEY(supervisor_id) REFERENCES "UserId" (system_unique_id), 
         CONSTRAINT person_assistant_id_fk FOREIGN KEY(assistant_id) REFERENCES "UserId" (system_unique_id)
);
CREATE INDEX ix_person_assistant_id ON person (assistant_id);
CREATE INDEX ix_person_supervisor_id ON person (supervisor_id);

CREATE TABLE tag (
        id INTEGER NOT NULL, 
        name TEXT, 
        PRIMARY KEY (id)
);

CREATE SEQUENCE tag_id_seq;

CREATE TABLE person_watched_people__person (
        person_id1 INTEGER NOT NULL, 
        person_id2 INTEGER NOT NULL, 
        PRIMARY KEY (person_id1, person_id2), 
         CONSTRAINT person_watched_people_fk FOREIGN KEY(person_id1) REFERENCES "UserId" (system_unique_id), 
         CONSTRAINT person_watched_people_inverse_fk FOREIGN KEY(person_id2) REFERENCES "UserId" (system_unique_id)
);

CREATE TABLE tag_people__person_tags (
        person_id INTEGER NOT NULL, 
        tag_id INTEGER NOT NULL, 
        PRIMARY KEY (person_id, tag_id), 
         CONSTRAINT person_tags_fk FOREIGN KEY(person_id) REFERENCES "UserId" (system_unique_id), 
         CONSTRAINT tag_people_fk FOREIGN KEY(tag_id) REFERENCES tag (id)
);

INSERT INTO person (id, name) SELECT user_id, username FROM "User";

CREATE LANGUAGE plpgsql;

CREATE FUNCTION auto_vivify_person () RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO person (id, name) values (NEW.system_unique_id, NEW.driver_username);
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER person_ins AFTER INSERT ON "UserId"
    FOR EACH ROW EXECUTE PROCEDURE auto_vivify_person();

