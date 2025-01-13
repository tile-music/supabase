// import required libraries and modules
import { assert } from 'https://deno.land/std@0.192.0/testing/asserts.ts';
// import { createClient, SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { validateDisplayDataRequest } from '../get-display-data/index.ts';
import type { DisplayDataRequest } from '../../../../../lib/Request.ts';

Deno.test("Test valid display data request", () => {
    const validRequest = {
        aggregate: "song",
        num_cells: 10,
        date: { start: 	1731622742500, end: 1735406362000},
        rank_determinant: "listens"
    };

    function testValidDisplayDataRequest(request: unknown, name: string) {
        let result: null | DisplayDataRequest = null;
        try { result = validateDisplayDataRequest(request); }
        catch (error) { assert(!error, name + " request should not return an error"); }
        assert(result !== null, name + " request should return a verified request object");
    }

    // basic request
    testValidDisplayDataRequest(validRequest, "Valid");

    // aggregate
    testValidDisplayDataRequest({...validRequest, aggregate: "album"}, "Album aggregate");

    // num_cells
    testValidDisplayDataRequest({...validRequest, num_cells: 1}, "Single cell");
    testValidDisplayDataRequest({...validRequest, num_cells: 100}, "Many cells");

    // date
    testValidDisplayDataRequest({...validRequest,
        date: { start: null, end: 1735406362000 }
    }, "Null start date");
    testValidDisplayDataRequest({...validRequest,
        date: { start: 1731622742500, end: null }
    }, "Null end date");
    testValidDisplayDataRequest({...validRequest,
        date: { start: 1731622742500, end: 1931622742500 }
    }, "Future end date");

    // rank_determinant
    testValidDisplayDataRequest({...validRequest, rank_determinant: "time"}, "Time rank determinant");    
});

Deno.test("Test invalid display data request", () => {
    const validRequest = {
        aggregate: "song",
        num_cells: 10,
        date: { start: 1731622742500, end: 1735406362000},
        rank_determinant: "listens"
    };

    function testInvalidDisplayDataRequest(request: unknown, name: string) {
        let result: null | DisplayDataRequest = null;
        try { result = validateDisplayDataRequest(request); }
        catch (error) { assert(error, name + " request should return an error"); }
        assert(result == null, name + " request should not return a request object");
    }

    // aggregate
    testInvalidDisplayDataRequest({...validRequest, aggregate: "test"}, "Invalid aggregate");
    testInvalidDisplayDataRequest({...validRequest, aggregate: undefined}, "Undefined aggregate");

    // num_cells
    testInvalidDisplayDataRequest({...validRequest, num_cells: -1}, "Negative num_cells");
    testInvalidDisplayDataRequest({...validRequest, num_cells: 0}, "Zero num_cells");
    testInvalidDisplayDataRequest({...validRequest, num_cells: 0.1}, "Non-integer num_cells");
    testInvalidDisplayDataRequest({...validRequest, num_cells: "10"}, "Non-number num_cells");
    testInvalidDisplayDataRequest({...validRequest, num_cells: undefined}, "Undefined num_cells");

    // date
    testInvalidDisplayDataRequest({...validRequest, date: undefined }, "Undefined date");
    testInvalidDisplayDataRequest({...validRequest, date: null }, "Null date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { start: undefined, end: 1735406362000 }
    }, "Undefined start date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { start: 1731622742500, end: undefined }
    }, "Undefined end date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { end: 1735406362000 }
    }, "Missing start date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { start: 1731622742500 }
    }, "Missing end date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { start: "1731622742500", end: 1735406362000 }
    }, "Non-integer start date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { start: 1731622742500, end: "1735406362000" }
    }, "Non-integer end date");
    testInvalidDisplayDataRequest({...validRequest,
        date: { start: 1735406362000, end: 1731622742500 }
    }, "End date before start date");

    // rank_determinant
    testInvalidDisplayDataRequest({...validRequest, rank_determinant: undefined}, "Undefined rank_determinant");
    testInvalidDisplayDataRequest({...validRequest, rank_determinant: "test"}, "Invalid rank_determinant");
});